class Dtype(object):
    def __init__(self, op_str):
        self.op_str = op_str
    def __str__(self):
        return str(self.op_str)
    def __eq__(self, other):
        if isinstance(other, self):
            return other.bits == self.bits
        else: return False        
    def __ne__(self, other):
        return not self.__eq__(other)
    
class FixedPoint(Dtype):
    def __init__(self, bits, frac_bits):
        self.op_str = 'FXP{}'.format(bits)
        self.bits = bits
        self.frac_bits = frac_bits
        self.int_bits = self.bits - self.frac_bits
    def __str__(self):
        return '{} ({},{})'.format(super(FixedPoint, self).__str__(), self.int_bits, self.frac_bits)
    def __eq__(self, other):
        if isinstance(other, FixedPoint):
            return other.bits == self.bits and other.frac_bits == self.frac_bits
        else:
            return False
    def __ne__(self, other):
        result = not self.__eq__(other)
        return result

class Log(Dtype):
    def __init__(self, exp_bits):
        self.op_str = 'Log{}'.format(exp_bits)
        self.bits = 2
        self.exp_bits = exp_bits
    
class Binary(FixedPoint):
    def __init__(self):
        self.bits = 1
        self.op_str = 'Binary'
        self.frac_bits = 0
        self.int_bits = 1
    def __str__(self):
        return 'Binary'
        
class CustomFloat(Dtype):
    def __init__(self, bits, exp_bits):
        self.bits = bits
        self.exp_bits = exp_bits
        self.op_str = 'Custom Float({},{})'.format(self.bits, self.exp_bits)      
        
class Float(Dtype):
    def __init__(self, bits):
        assert bits in (16, 32)
        self.bits = bits
        self.op_str = 'FP{}'.format(self.bits)

class DTypes(object):
    FP32 = Float(32)
    FP16 = Float(16)
    FXP32 = FixedPoint(32,16)
    FXP16 = FixedPoint(16,8)
    FXP8 = FixedPoint(8,8)
    FXP4 = FixedPoint(4,4)
    FXP2 = FixedPoint(2,2)
    Bin = Binary()
    FXP6 = FixedPoint(6,6)
    Log6 = Log(6)
    Log4 = Log(4)
    FP_16_5 = CustomFloat(16, 5)
    FP_12_5 = CustomFloat(12, 5)
    FP_8_5 = CustomFloat(8, 5)

FQDtype = DTypes()
