class Stats(object):
    """
    Stores the stats from the simulator
    """

    def __init__(self):
        self.total_cycles = 0
        self.mem_stall_cycles = 0
        self.namespaces = ['ibuf', 'wbuf', 'obuf', 'bbuf', 'dram']
        self.reads = {}
        self.writes = {}
        for n in self.namespaces:
            self.reads[n] = 0
            self.writes[n] = 0

    def __iter__(self):
        return iter([\
                     self.total_cycles,
                     self.mem_stall_cycles,
                     self.reads['ibuf'],
                     self.reads['wbuf'],
                     self.reads['bbuf'],
                     self.reads['obuf'],
                     self.reads['dram'],
                     self.writes['obuf'],
                     self.writes['dram']
                    ])

    def __add__(self, other):
        ret = Stats()
        ret.total_cycles = self.total_cycles + other.total_cycles
        ret.mem_stall_cycles = self.mem_stall_cycles + other.mem_stall_cycles
        for n in self.namespaces:
            ret.reads[n] = self.reads[n] + other.reads[n]
            ret.writes[n] = self.writes[n] + other.writes[n]
        return ret

    def __mul__(self, other):
        ret = Stats()
        ret.total_cycles = self.total_cycles * other
        ret.mem_stall_cycles = self.mem_stall_cycles * other
        for n in self.namespaces:
            ret.reads[n] = self.reads[n] * other
            ret.writes[n] = self.writes[n] * other
        return ret

    def __str__(self):
        ret = '\tStats'
        ret+= '\n\t{0:>20}   : {1:>20,}, '.format('Total cycles', self.total_cycles)
        ret+= '\n\t{0:>20}   : {1:>20,}, '.format('Memory Stalls', self.mem_stall_cycles)
        ret+= '\n\tReads: '
        for n in self.namespaces:
            ret+= '\n\t{0:>20} rd: {1:>20,} bits, '.format(n, self.reads[n])
        ret+= '\n\tWrites: '
        for n in self.namespaces:
            ret+= '\n\t{0:>20} wr: {1:>20,} bits, '.format(n, self.writes[n])
        return ret

    def get_energy(self, energy_cost, dram_cost=6.e-3):
        leak_cost, core_dyn_cost, wbuf_read_cost, wbuf_write_cost, ibuf_read_cost, ibuf_write_cost, bbuf_read_cost, bbuf_write_cost, obuf_read_cost, obuf_write_cost = energy_cost
        dyn_energy = (self.total_cycles - self.mem_stall_cycles) * core_dyn_cost

        dyn_energy += self.reads['wbuf'] * wbuf_read_cost
        dyn_energy += self.writes['wbuf'] * wbuf_write_cost

        dyn_energy += self.reads['ibuf'] * ibuf_read_cost
        dyn_energy += self.writes['ibuf'] * ibuf_write_cost

        dyn_energy += self.reads['bbuf'] * bbuf_read_cost
        dyn_energy += self.writes['bbuf'] * bbuf_write_cost

        dyn_energy += self.reads['obuf'] * obuf_read_cost
        dyn_energy += self.writes['obuf'] * obuf_write_cost

        # Assuming that the DRAM requires 6 pJ/bit
        dyn_energy += self.reads['dram'] * dram_cost
        dyn_energy += self.writes['dram'] * dram_cost

        # Leakage Energy
        leak_energy = self.total_cycles * leak_cost * 0
        return dyn_energy + leak_energy

    def get_energy_breakdown(self, energy_cost, dram_cost=6.e-3):
        leak_cost, core_dyn_cost, wbuf_read_cost, wbuf_write_cost, ibuf_read_cost, ibuf_write_cost, bbuf_read_cost, bbuf_write_cost, obuf_read_cost, obuf_write_cost = energy_cost
        core_energy = (self.total_cycles - self.mem_stall_cycles) * core_dyn_cost
        breakdown = [core_energy]

        sram_energy = self.reads['wbuf'] * wbuf_read_cost
        sram_energy += self.writes['wbuf'] * wbuf_write_cost

        sram_energy += self.reads['ibuf'] * ibuf_read_cost
        sram_energy += self.writes['ibuf'] * ibuf_write_cost

        sram_energy += self.reads['bbuf'] * bbuf_read_cost
        sram_energy += self.writes['bbuf'] * bbuf_write_cost

        sram_energy += self.reads['obuf'] * obuf_read_cost
        sram_energy += self.writes['obuf'] * obuf_write_cost

        breakdown.append(sram_energy)
        breakdown.append(0)
        dram_energy = self.reads['dram'] * dram_cost
        dram_energy += self.writes['dram'] * dram_cost
        breakdown.append(dram_energy)
        return breakdown

def get_energy_from_results(results, acc_obj):
    stats = Stats()
    stats.total_cycles = int(results['Cycles'])
    stats.mem_stall_cycles = int(results['Memory wait cycles'])
    stats.reads['ibuf'] = int(results['IBUF Read'])
    stats.reads['obuf'] = int(results['OBUF Read'])
    stats.reads['wbuf'] = int(results['WBUF Read'])
    stats.reads['dram'] = int(results['DRAM Read'])
    stats.writes['ibuf'] = int(results['IBUF Write'])
    stats.writes['obuf'] = int(results['OBUF Write'])
    stats.writes['wbuf'] = int(results['WBUF Write'])
    stats.writes['dram'] = int(results['DRAM Write'])
    energy = stats.get_energy(acc_obj)
    return energy

