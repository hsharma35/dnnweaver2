from dnnweaver2.scalar.dtypes import Dtype

class ScalarOp(object):
    def __init__(self, op_str, dtype):
        self.op_str = op_str
        self.dtype = dtype
    def __str__(self):
        if isinstance(self.dtype, Dtype):
            return '{}({})'.format(self.op_str, self.dtype.__str__())
        else:
            ret = str(self.op_str)
            ret += '('
            ret += ','.join([x.__str__() for x in self.dtype])
            ret += ')'
            return ret


class ScalarOpTypes(object):
    def __init__(self):
        self.MulOp = {}
        self.MacOp = {}
        self.SqrOp = {}
        self.CmpOp = {}
        self.AddOp = {}
        self.SubOp = {}
        self.RshiftOp = {}
    def MUL(self, dtypes):
        assert len(dtypes) == 2
        if dtypes not in self.MulOp:
            self.MulOp[dtypes] = ScalarOp('Multiply', dtypes)
        return self.MulOp[dtypes]
    def MAC(self, dtypes):
        assert len(dtypes) == 3
        if dtypes not in self.MacOp:
            self.MacOp[dtypes] = ScalarOp('Multiply-Accumulate', dtypes)
        return self.MacOp[dtypes]
    def SQR(self, dtypes):
        assert isinstance(dtypes, Dtype)
        if dtypes not in self.SqrOp:
            self.SqrOp[dtypes] = ScalarOp('Square', dtypes)
        return self.SqrOp[dtypes]
    def CMP(self, dtypes):
        assert isinstance(dtypes, Dtype), 'Got Dtypes: {}'.format(dtypes)
        if dtypes not in self.CmpOp:
            self.CmpOp[dtypes] = ScalarOp('Compare', dtypes)
        return self.CmpOp[dtypes]
    def ADD(self, dtypes):
        assert len(dtypes) == 2
        if dtypes not in self.AddOp:
            self.AddOp[dtypes] = ScalarOp('Addition', dtypes)
        return self.AddOp[dtypes]
    def SUB(self, dtypes):
        assert len(dtypes) == 2
        if dtypes not in self.SubOp:
            self.SubOp[dtypes] = ScalarOp('Subtract', dtypes)
        return self.SubOp[dtypes]
    def RSHIFT(self, dtypes):
        assert isinstance(dtypes, Dtype), 'Got Dtypes: {}'.format(dtypes)
        if dtypes not in self.RshiftOp:
            self.RshiftOp[dtypes] = ScalarOp('Rshift', dtypes)
        return self.RshiftOp[dtypes]


Ops = ScalarOpTypes()
