class XorShift32
  attr_accessor(:a, :b, :c, :v)
  def initialize(a_, b_, c_, v_)
    self.a = a_
    self.b = b_
    self.c = c_
    self.v = v_
  end

  def next()
    _v = self.v
    _v = _v ^ ((_v << self.a) & 0xFFFFFFFF)
    _v = _v ^ ((_v >> self.b) & 0xFFFFFFFF)
    _v = _v ^ ((_v << self.c) & 0xFFFFFFFF)
    self.v = _v
    return v
  end
end
