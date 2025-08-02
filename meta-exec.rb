#!/usr/bin/env ruby
require "./xorshift32.rb"
Opts = {
  "a" => 3,
  "b" => 13,
  "c" => 7,
  "seed" => "01234567012345670123456701234567",
  "seed-base64" => "EjRWeBI0VngSNFZ4EjRWeA",
  "dir" => "./",
  "mesh" => 16,
  "strength" => 20,
  "noise-subtract" => 20,
  "noise-add" => 0,
  "width" => 14,
  "height" => 14,
  "erode-dilate" => "0:0",
  "aspect-range-x" => nil,
  "aspect-range-y" => nil,
  "apply-aspect" => "g",
  "fill-extent" => false,
  "jump-random-per-glyph" => 512,
  "fonts" => [],
  "args" => []
}
require "getOpts.rb"
if (Opts.include?("auto-seed"))
  require "digest/xxhash"
end

if (Opts["seed-base64"] != nil)
  Opts["seed"] = XorShift128p_u32.dec64(Opts["seed-base64"]).unpack1("H*")
end

def get_font_base(path_font)
  return path_font.split("/").last.gsub(/\.[0-9A-Za-z]{3,4}$/, "")
end

if (!Opts.include?("font"))
  Opts.args.each{|f| Opts["fonts"].push(f)}
end
# p Opts

# === INITIALIZE FREETYPE ===
require "./freetype-class.rb"

ft_lib_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_Init_FreeType(ft_lib_ptr)
raise "FT_Init_FreeType() failed" unless ft_err == 0
ft_lib = ft_lib_ptr.read_pointer()

# === RENDER GLYPH ===
def proc_gid(ft_face, path_font, gid, ucs, prng)
  ft_err = FreeType::C.FT_Load_Glyph(ft_face, gid, FreeType::C::FT_LOAD_RENDER)
  return unless ft_err == 0

  base_font = get_font_base(path_font)

  ft_glyphslot_ptr = ft_face[:glyph]
  ft_glyphslot = FT_GlyphSlotRec.new(ft_glyphslot_ptr)
  ft_err = FreeType::C.FT_Render_Glyph(ft_glyphslot_ptr, 0)
  return unless ft_err == 0
  ft_bitmap = ft_glyphslot[:bitmap]

  glyph_width  = ft_bitmap[:width]
  glyph_height = ft_bitmap[:rows]
  return if glyph_width == 0 || glyph_height == 0

  prng_sthd = prng.get_state_hexdigit()
  prng_st64 = prng.get_state_base64()
  printf("# prng_sthd:%s, prng_st64:%s\n", prng_sthd, prng_st64)

  if (Opts.include?("cmd"))
    cmd = [ "./gen-distorted-glyph.rb" ]
    cmd << sprintf("--mesh=%d", Opts.mesh)
    cmd << sprintf("--font=%s", path_font)
    cmd << sprintf("--gid=%d", gid)
    cmd << sprintf("--height=%d", Opts.height)
    cmd << sprintf("--seed-base64=%s", prng_st64)
    cmd << sprintf("--strength=%d", Opts.strength)
    cmd << sprintf("--noise-subtract=%d", Opts.noise_subtract) if (Opts.include?("noise-subtract"))
    cmd << sprintf("--noise-sub=%s", Opts.noise_sub) if (Opts.include?("noise-sub"))
    cmd << sprintf("--noise-add=%s", Opts.noise_add.to_s())
    cmd << sprintf("--erode-dilate=%s", Opts.erode_dilate) if (Opts.include?("erode-dilate"))
    cmd << sprintf("--aspect-range-x=%s", Opts["aspect-range-x"]) if (Opts["aspect-range-x"] != nil)
    cmd << sprintf("--aspect-range-y=%s", Opts["aspect-range-y"]) if (Opts["aspect-range-y"] != nil)
    cmd << sprintf("--apply-aspect=%s", Opts["apply-aspect"]) if (Opts["apply-aspect"] != nil)
    cmd << sprintf("--fill-extent") if (Opts.include?("fill-extent"))
    if (ucs != nil)
      cmd << sprintf("--output=%s_%s_pw%02d_sub%02d_add%02d_B64=%s.png",
        [Opts.dir, base_font].join("/"), ucs,
        Opts.strength, Opts.noise_subtract, Opts.noise_add, prng_st64
      )
    else
      cmd << sprintf("--output=%s_g%05d_pw%02d_sub%02d_add%02d_B64=%s.png",
        [Opts.dir, base_font].join("/"), gid,
        Opts.strength, Opts.noise_subtract, Opts.noise_add, prng_st64
      )
    end
    puts cmd.join(" ")
  else
    printf("font=%s gid=%d bitmap=%dx%d sd=%s\n", path_font, gid, glyph_width, glyph_height, prng_st64)
  end
  prng.jump(Opts.jump_random_per_glyph)
  # FT_New_Glyph() is not called, so no need to Done something.
  # ft_err = FreeType::C.FT_Done_Glyph(ft_glyphslot_ptr)
end

def proc_font(ft_lib, path_font, prng)
  # === INITIALIZE FREETYPE ===
  ft_face_ptr = FFI::MemoryPointer.new(:pointer)
  ft_err = FreeType::C.FT_New_Face(ft_lib, path_font, 0, ft_face_ptr)
  raise "FT_New_Face() failed" unless ft_err == 0
  ft_face = FT_FaceRec.new(ft_face_ptr.read_pointer())

  # === SET PIXEL SIZE ===
  ft_err = FreeType::C.FT_Set_Pixel_Sizes(ft_face, Opts.width, Opts.height)
  raise "FT_Set_Pixel_Sizes() failed" unless ft_err == 0

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
    gid_ucs.each{|a| proc_gid(ft_face, path_font, a[0], a[1], prng)}
  else
    (0..ft_face[:num_glyphs]).to_a().each{|gid| proc_gid(ft_face, path_font, gid, nil, prng)}
  end
  FreeType::C.FT_Done_Face(ft_face)
end

if (Opts.include?("auto-seed"))
  seed_tokens = []
  seed_tokens << ("mesh=" + Opts.mesh.to_s())
  seed_tokens << ("strength=" + Opts.strength.to_s())
  seed_tokens << ("noise-subtract=" + Opts.noise_subtract.to_s())
  seed_tokens << ("noise-add=" + Opts.noise_add.to_s())
  seed_tokens << ("erode-dilate=" + Opts.erode_dilate)
  seed_tokens << ("aspect-range-x=" + Opts["aspect-range-x"]) if (Opts["aspect-range-x"] != nil)
  seed_tokens << ("aspect-range-y=" + Opts["aspect-range-y"]) if (Opts["aspect-range-y"] != nil)
  seed_tokens << ("apply-aspect=" + Opts["apply-aspect"]) if (Opts["apply-aspect"] != nil)
  seed_tokens << ("fill-extent") if (Opts.include?("fill-extent"))
  seed_tokens << ("jump-random-per-glyph=" + Opts.jump_random_per_glyph.to_s())
  # sd = Digest::XXH32.hexdigest(seed_tokens.join("\t"))
  Opts["seed"] = Digest::XXH3_128bits.hexdigest(seed_tokens.join("\t"))
end

prng = XorShift128p_u32.new(Opts.a, Opts.b, Opts.c, Opts.seed)
printf("# xorshift128+\n")
printf("#   a:%d, b:%d, c:%d\n", prng.a, prng.b, prng.c)
printf("#   stat:[ 0x%08x, 0x%08x, 0x%08x, 0x%08x ]\n", prng.v[0], prng.v[1], prng.v[2], prng.v[3])

if (Opts.include?("font"))
  proc_font(ft_lib, Opts.font, prng)
else
  Opts.fonts.each{|f| proc_font(ft_lib, f, prng)}
end
printf("# total random number consumation 0x%08x = %d\n", prng.count, prng.count)
printf("# xorshift128+\n")
printf("#   a:%d, b:%d, c:%d\n", prng.a, prng.b, prng.c)
printf("#   stat:[ 0x%08x, 0x%08x, 0x%08x, 0x%08x ]\n", prng.v[0], prng.v[1], prng.v[2], prng.v[3])
# ft_err = FreeType::C.FT_Done_FreeType(ft_lib)
