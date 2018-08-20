import numpy as np

from dnnweaver2.simulator.stats import Stats

class LoopStack(object):
    def __init__(self, size=1024):
        self.loop_stack = np.empty(size, dtype=Instruction)
        self.head_ptr = 0
        self.tail_ptr = 0
        self.loop_count = 0
        self.mem_read_count = 0
        self.mem_write_count = 0

        self.mem_ops = []
        self.compute_ops = []

    def insert_compute(self, op, *args):
        self.compute_ops.append(ComputeInstruction(op, *args))

    def insert_mem_read(self, namespace, addr, size, stride, level=0, name=None):

        if name is None:
            name = 'mem_rd_{0}'.format(self.mem_read_count)

        mem_rd = MemoryReadInstruction(name=name,
                                       namespace=namespace,
                                       addr=addr,
                                       size=size,
                                       stride=stride,
                                       level=level)
        self.mem_ops.append(mem_rd)
        self.insert_instruction(mem_rd)

    def insert_mem_write(self, namespace, addr, size, stride, level=0, name=None):
        if name is None:
            name = 'mem_wr_{0}'.format(self.mem_write_count)

        mem_wr = MemoryWriteInstruction(name=name,
                                        namespace=namespace,
                                        addr=addr,
                                        size=size,
                                        stride=stride,
                                        level=level)
        self.mem_ops.append(mem_wr)
        self.insert_instruction(mem_wr)

    def insert_loop(self, loop_count, stride, level=0, name=None):
        if name is None:
            name = 'loop_{}'.format(self.loop_count)
        self.loop_count += 1
        loop = LoopInstruction(name=name,
                               loop_count=loop_count,
                               stride=stride,
                               level=level)

        self.insert_instruction(loop)

    def insert_instruction(self, inst):
        level = inst.level
        if self.loop_stack[self.head_ptr] is None:
            self.loop_stack[self.tail_ptr] = inst
            self.tail_ptr = 1
        else:
            l = self.loop_stack[self.head_ptr]
            assert l.level <= level
            if l.level < level:
                l.set_loop_with_level(level, inst)
                self.loop_stack[self.tail_ptr] = inst
                self.tail_ptr += 1
            else:
                self.head_ptr = self.tail_ptr
                self.loop_stack[self.tail_ptr] = inst
                self.tail_ptr += 1

    def promote_mem_ops(self, sram):
        for op in self.mem_ops:
            old = op.outer_loop
            if old is None:
                continue
            else:
                old.inner_loop.remove(op)
            curr = old
            namespace = op.namespace
            while curr is not None and (curr.stride[namespace] == 0 or sram[namespace] > op.size * curr.loop_count):
                if curr.stride[namespace] != 0:
                    op.size *= curr.loop_count
                curr = curr.outer_loop
            if curr is not None:
                if isinstance(op, MemoryWriteInstruction):
                    curr.inner_loop.append(op)
                else:
                    curr.inner_loop.insert(0, op)
                op.outer_loop = curr
                op.level = curr.level + 1
            else:
                op.level = 0
                op.outer_loop = None

    def __str__(self):
        ret = ''
        for l in self.loop_stack:
            if l is not None and l.level == 0:
                ret += '*' * 50 + '\n'
                ret += l.__str__() + '\n'
        ret += '*' * 50 + '\n'
        return ret

    def get_stats(self, acc_obj, verbose=False):
        stats = {}
        stats['total'] = Stats()
        for l in self.loop_stack:
            if l is not None and l.level == 0 and isinstance(l, LoopInstruction):
                stats[l.name] = l.get_stats(acc_obj, self.mem_ops, self.compute_ops, top=True)
                stats['total'] += stats[l.name]
        return stats


class Instruction(object):
    def __init__(self, type=None):
        self.inner_loop = []
        self.outer_loop = None

    def __str__(self, l=0):
        raise NotImplementedError('STR not implemented')

    def get_stats(self, acc_obj, mem_ops, compute_ops, top=False):
        raise NotImplementedError('get_stats not implemented')

class ComputeInstruction(Instruction):
    def __init__(self, op, *args):
        Instruction.__init__(self)
        self.op = op
        self.args = args

    def __str__(self, l=0):
        ret = 'Compute Op: Args = {}'.format(self.args)
        return ret

    def get_stats(self, acc_obj):
        stats = self.op(*self.args)
        return stats


class MemoryReadInstruction(Instruction):
    def __init__(self, name, namespace, addr, size, stride, level=0):
        Instruction.__init__(self)
        assert namespace in ['act', 'wgt', 'out']
        self.name = name
        self.namespace = namespace
        self.base_addr = addr
        self.size = size
        self.stride = stride
        self.level = level

    def __str__(self, l=0):
        ret = ' | ' * l + ('{0}: addr {1}, size {2}, stride {3}').format(self.name,
                                                                         self.base_addr,
                                                                         self.size,
                                                                         self.stride)
        ret += ', level: {}'.format(self.level)
        return ret

    def get_stats(self, acc_obj, mem_ops, compute_ops, top=False):
        stats = Stats()
        read_cycles = acc_obj.get_mem_read_cycles(self.namespace, self.size)
        if read_cycles is not None:
            stats.total_cycles = read_cycles
            stats.mem_stall_cycles = read_cycles
            stats.writes[self.namespace] = self.size
            stats.reads['dram'] = self.size
        return stats


class MemoryWriteInstruction(Instruction):
    def __init__(self, name, namespace, addr, size, stride, level=0):
        Instruction.__init__(self)
        assert namespace in ['act', 'wgt', 'out']
        self.name = name
        self.namespace = namespace
        self.base_addr = addr
        self.size = size
        self.stride = stride
        self.level = level

    def __str__(self, l=0):
        ret = ' | ' * l + ('{0}: addr {1}, size {2}, stride {3}').format(self.name,
                                                                         self.base_addr,
                                                                         self.size,
                                                                         self.stride)
        ret += ', level: {}'.format(self.level)
        return ret

    def get_stats(self, acc_obj, mem_ops, compute_ops, top=False):
        stats = Stats()
        write_cycles = acc_obj.get_mem_write_cycles(self.namespace, self.size)
        if write_cycles is not None:
            stats.total_cycles = write_cycles
            stats.mem_stall_cycles = write_cycles
            stats.reads[self.namespace] = self.size
            stats.writes['dram'] = self.size
        return stats

class LoopInstruction(Instruction):
    def __init__(self, name, loop_count, stride, level=0):
        Instruction.__init__(self)
        self.name = name
        self.loop_count = loop_count
        self.stride = stride
        self.level = level

    def __str__(self, l=0):
        ret = ' | ' * l + '{0}: Range {1}, stride {2}'.format(self.name,
                                                              self.loop_count,
                                                              self.stride)
        for il in self.inner_loop:
            ret += '\n{}'.format(il.__str__(l + 1))
        return ret

    def set_loop_with_level(self, level, loop):
        assert level > self.level
        if level == self.level + 1:
            self.inner_loop.append(loop)
            loop.outer_loop = self
        else:
            if len(self.inner_loop) == 0:
                raise IndexError(
                    'Inserting loop {0} with level {1} into loop {2} with level {3}'.format(loop.name, loop.level,
                                                                                            self.name, self.level))
            self.inner_loop[-1].set_loop_with_level(level, loop)

    def get_pipe_stats(self, acc_obj, mem_ops, compute_ops, top=False):

        rd_stats = Stats()
        pipe_stats = []
        compute_stats = Stats()
        wr_stats = Stats()

        for il in self.inner_loop:
            if isinstance(il, MemoryReadInstruction):
                rd_stats += il.get_stats(acc_obj, mem_ops, compute_ops) * self.loop_count
            elif isinstance(il, MemoryWriteInstruction):
                wr_stats += il.get_stats(acc_obj, mem_ops, compute_ops) * self.loop_count

        il_count = 0
        for il in self.inner_loop:
            if isinstance(il, LoopInstruction):
                il_count += 1

        if il_count == 0:
            for cop in compute_ops:
                compute_stats += cop.get_stats(acc_obj)
            pipeline = Pipeline(compute_stats.total_cycles, rd_stats.total_cycles//self.loop_count, wr_stats.total_cycles//self.loop_count, self.loop_count)
            total_stats = rd_stats + compute_stats * self.loop_count + wr_stats
            total_stats.total_cycles = pipeline.get_cycles()
            total_stats.mem_stall_cycles = total_stats.total_cycles - compute_stats.total_cycles * self.loop_count
        else:
            for il in self.inner_loop:
                count = 0
                if isinstance(il, LoopInstruction):
                    count += 1
                    assert count == 1
                    pipe, il_stats = il.get_pipe_stats(acc_obj, mem_ops, compute_ops)
                    pipeline = Pipeline(pipe, rd_stats.total_cycles//self.loop_count, wr_stats.total_cycles//self.loop_count, self.loop_count)
                    total_stats = rd_stats + il_stats * self.loop_count + wr_stats
                    total_stats.total_cycles = pipeline.get_cycles()
                    total_stats.mem_stall_cycles = total_stats.total_cycles - (il_stats.total_cycles - il_stats.mem_stall_cycles) * self.loop_count

        # print(self.name)
        # print(pipeline)
        # print(total_stats)

        return pipeline, total_stats


    def get_stats(self, acc_obj, mem_ops, compute_ops, top=True):
        pipe, stats = self.get_pipe_stats(acc_obj, mem_ops, compute_ops, top=True)
        if top:
            for mop in mem_ops:
                if mop.level == 0:
                    stats += mop.get_stats(acc_obj, mem_ops, compute_ops)
        return stats
