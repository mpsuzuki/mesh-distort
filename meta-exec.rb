#!/usr/bin/env ruby

Opts = {
  "a" => 3,
  "b" => 13,
  "c" => 7,
  "seed" => "0xDEADBEEF",
  "dir" => "./",
  "mesh" => 16,
  "strength" => 20,
  "noise-subtract" => 20,
  "noise-add" => 0,
  "width" => 14,
  "height" => 14
}
require "getOpts.rb"
if (Opts["seed"] != nil)
  Opts["seed"] = Opts["seed"].hex()
end

Opts["font-base"] = Opts.font.split("/").last.gsub(/\.[0-9A-Za-z]{3,4}$/, "")

# === INITIALIZE FREETYPE ===
require "./freetype-class.rb"

ft_lib_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_Init_FreeType(ft_lib_ptr)
raise "FT_Init_FreeType() failed" unless ft_err == 0
ft_lib = ft_lib_ptr.read_pointer()

# === INITIALIZE FREETYPE ===
ft_face_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_New_Face(ft_lib, Opts.font, 0, ft_face_ptr)
raise "FT_New_Face() failed" unless ft_err == 0
ft_face = FT_FaceRec.new(ft_face_ptr.read_pointer())

# === SET PIXEL SIZE ===
ft_err = FreeType::C.FT_Set_Pixel_Sizes(ft_face, Opts.width, Opts.height)
raise "FT_Set_Pixel_Sizes() failed" unless ft_err == 0

# === RENDER GLYPH ===
require "./xorshift32.rb"
xorshift32 = XorShift32.new(Opts.a, Opts.b, Opts.c, Opts.seed)


def proc_gid(ft_face, gid, ucs, xorshift32)
  ft_err = FreeType::C.FT_Load_Glyph(ft_face, gid, FreeType::C::FT_LOAD_RENDER)
  return unless ft_err == 0

  ft_glyphslot_ptr = ft_face[:glyph]
  ft_glyphslot = FT_GlyphSlotRec.new(ft_glyphslot_ptr)
  ft_err = FreeType::C.FT_Render_Glyph(ft_glyphslot_ptr, 0)
  return unless ft_err == 0
  ft_bitmap = ft_glyphslot[:bitmap]

  glyph_width  = ft_bitmap[:width]
  glyph_height = ft_bitmap[:rows]
  return if glyph_width == 0 || glyph_height == 0

  if (Opts.include?("cmd"))
    sd = xorshift32.next()
    cmd = [ "./gen-distorted-glyph.rb" ]
    cmd << sprintf("--mesh=%d", Opts.mesh)
    cmd << sprintf("--font=%s", Opts.font)
    cmd << sprintf("--gid=%d", gid)
    cmd << sprintf("--height=%d", Opts.height)
    cmd << sprintf("--seed=0x%08x", sd)
    cmd << sprintf("--strength=%d", Opts.strength)
    cmd << sprintf("--noise-subtract=%d", Opts.noise_subtract)
    cmd << sprintf("--noise-add=%d", Opts.noise_add)
    if (ucs != nil)
      cmd << sprintf("--output=%s_%s_pw%02d_sub%02d_add%02d_sdx%08x.png",
        [Opts.dir, Opts.font_base].join("/"), ucs,
        Opts.strength, Opts.noise_subtract, Opts.noise_add, sd
      )
    else
      cmd << sprintf("--output=%s_g%05d_pw%02d_sub%02d_add%02d_sdx%08x.png",
        [Opts.dir, Opts.font_base].join("/"), gid,
        Opts.strength, Opts.noise_subtract, Opts.noise_add, sd
      )
    end
    puts cmd.join(" ")
  else
    printf("gid=%d bitmap=%dx%d seed=0x%08x\n", gid, glyph_width, glyph_height, xorshift32.next())
  end
end

if (Opts.include?("ucs-range"))
  gid_ucs = Array.new()
  Opts.ucs_range.split(",").each do |rng|
    rng_first, rng_last = rng.split("..").map{|t| t.gsub(/^[Uu]+/, "").hex()}
    u = rng_first
    while (u < rng_last) do
      _gid = FreeType::C.FT_Get_Char_Index(ft_face, u)
      gid_ucs << [_gid, sprintf("U+%04X", u)] if (_gid > 0)
      u += 1
    end
  end
  gid_ucs.each{|a| proc_gid(ft_face, a[0], a[1], xorshift32)}
else
  (0..ft_face[:num_glyphs]).to_a().each{|gid| proc_gid(ft_face, gid, nil, xorshift32)}
end
