class XorShift32
  attr_accessor(:a, :b, :c, :v, :count)
  def initialize(a_, b_, c_, v_)
    self.a = a_
    self.b = b_
    self.c = c_
    self.v = v_
    self.count = 0
  end

  def next()
    self.count += 1
    _v = self.v
    _v = _v ^ ((_v << self.a) & 0xFFFFFFFF)
    _v = _v ^ ((_v >> self.b) & 0xFFFFFFFF)
    _v = _v ^ ((_v << self.c) & 0xFFFFFFFF)
    self.v = _v
    return v
  end

  def jump(n)
    n.times.each do
      self.next()
    end
    return self
  end

end

require "base64"

class XorShift128p_u32
  def self.enc64(v)
    return Base64.urlsafe_encode64(v).tr("_=", ",~")
  end

  def self.dec64(s)
    return Base64.urlsafe_decode64(s.tr(",~", "_="))
  end


  attr_accessor(:a, :b, :c, :v, :count)
  def initialize(a_, b_, c_, vstr_ = "01234567012345670123456701234567")
    self.a = a_
    self.b = b_
    self.c = c_
    self.v = Array.new(4)
    vs = vstr_.scan(/.{8}/).map{|v| v.hex()}
    self.v[0] = vs[0]
    self.v[1] = vs[1]
    self.v[2] = vs[2]
    self.v[3] = vs[3]
    self.count = 0
  end

  def next()
    self.count += 1

    v0 = self.v[0]
    v3 = self.v[3]
    r = v0 + v3
    self.v.shift()

    v0 = v0 ^ ((v0 << self.a) & 0xFFFFFFFF)
    v0 = v0 ^ ((v0 >> self.b) & 0xFFFFFFFF)
    v3 = v3 ^ ((v0 >> self.c) & 0xFFFFFFFF)

    vn = v0 ^ v3

    self.v.push(vn)

    return r
  end

  def get_state_hexdigit()
    # return self.v.map{|vi| sprintf("%08x", vi)}.join("")
    return self.v.pack("N4").unpack("H*").first
  end

  def get_state_base64(raw = false)
    if (raw)
      return Base64.urlsafe_encode64( self.v.pack("N4") )
    else
      return XorShift128p_u32.enc64( self.v.pack("N4") )[0..21]
    end
  end

  def set_state_base64(state_b64_)
    XorShift128p_u32.dec64(state_b64_).unpack("N4").each_with_index do |int32,i|
      self.v[i] = int32
    end 
    return self
  end

  def jump(n)
    n.times.each do
      self.next()
    end
    return self
  end
end
