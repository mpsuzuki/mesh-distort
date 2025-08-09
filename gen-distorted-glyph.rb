#!/usr/bin/env ruby

Opts = {
  "a" => 4,
  "b" => 1,
  "c" => 5,
  "gid" => 0,
  "aa" => false,
  "utf8" => "A",
  "uhex" => nil,
  "seed" => nil,
  "seed-base64" => nil,
  "log" => nil,
  "strength" => "20:20",
  "noise-sub" => "20:20",
  "noise-add" => "0:0",
  "erode-dilate" => "0:0",
  "aspect-range-x" => nil,
  "aspect-range-y" => nil,
  "apply-aspect" => "g",
  "fill-extent" => false,
  "output" => "glyph.png",
  "mesh" => 1,
  "width" => 0,
  "height" => 32
}
require "getOpts.rb"
Opts["noise-sub"] = Opts["noise-subtract"] if (Opts.include?("noise-subtract"))
["strength", "noise-sub", "noise-add"].each do |k|
  if (Opts[k].class == String)
    vs = Opts[k].split(/[:;,^]/).map{|s| (s =~ /^[-+]?[0-9]+$/) ? s.to_i() : s.to_f()}
    Opts[k] = [vs[0 % vs.length], vs[1 % vs.length]]
  else
    Opts[k] = [Opts[k], Opts[k]]
  end
end

if (Opts["uhex"] != nil)
  Opts["uhex"] = Opts.uhex.gsub(/^[Uu]\+/, "").hex()
elsif (Opts["utf8"] != nil)
  Opts["uhex"] = Opts["utf8"].split("").first.encode("ucs-4be").unpack("N").first
end
if (Opts["erode-dilate"] != nil)
  vs = Opts["erode-dilate"].split(/[:;,^]/).map{|v| v.to_i()}
  Opts["erode-dilate"] = [vs[0 % vs.length], vs[1 % vs.length]]
end
require "./xorshift32.rb"
if (Opts["seed-base64"] != nil)
  # p Opts["seed-base64"].length
  # p XorShift128p_u32.dec64(Opts["seed-base64"]).length
  Opts["seed"] = XorShift128p_u32.dec64(Opts["seed-base64"]).unpack("H*").pop()
  printf("random seed is [")
  printf(Opts["seed"].scan(/.{8}/).map{|v| v.hex()}.map{|v| sprintf("0x%08x", v)}.join(", "))
  printf("]\n")
end
# p Opts["seed"].length
# p Opts
if (Opts["log"] == nil)
elsif (Opts["log"].downcase() == "stderr" || Opts["log"] == 2)
  Opts["log"] = STDERR
elsif (Opts["log"].downcase() == "stdout" || Opts["log"] == 1)
  Opts["log"] = STDOUT
else
  Opts["log"] = File::open(Opts["log"], "w")
end


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

# if (ft_face[:face_flags] & FreeType::C::FT_FACE_FLAG_MULTIPLE_MASTERS)
if (ft_face[:face_flags] & (1 << 8))
  puts("this font is multiple master or variable font")
end

# === INITIALIZE WEIGHT ===
ft_mm_var_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_Get_MM_Var(ft_face, ft_mm_var_ptr)
if (ft_err == 0)
  ft_mm_var = FT_MM_Var.new(ft_mm_var_ptr.read_pointer())
  puts "Number of axis: #{ft_mm_var[:num_axis]}"

  wght = Opts.var_wght
  wdth = Opts.var_wdth

  axis_ptr = ft_mm_var[:axis]
  num_axis = ft_mm_var[:num_axis]
  axis = Array.new(num_axis)
  coord_values = Array.new(num_axis)
  ft_mm_var[:num_axis].times do |axis_idx|
    axis[axis_idx] = FT_Var_Axis.new(axis_ptr + axis_idx * FT_Var_Axis.size)

    str_tag = [ axis[axis_idx][:tag] ].pack("N").encode("us-ascii")
    v_min = axis[axis_idx][:minimum]
    v_def = axis[axis_idx][:def]
    v_max = axis[axis_idx][:maximum]

    coord_values[axis_idx] = v_def
    is_def = "(def)"
    case (str_tag)
    when "wght" then
      if (Opts.var_wght != nil)
        is_def = ""
        coord_values[axis_idx] = [ [
          v_min,
          v_min + (v_max - v_min) * Opts.var_wght].max,
          v_max
        ].min
      end
    when "wdth" then
      if (Opts.var_wdth != nil)
        is_def = ""
        coord_values[axis_idx] = [ [
          v_min,
          v_min + (v_max - v_min) * Opts.var_wdth].max,
          v_max
        ].min
      end
    end

    printf("axis #%d - tag: %s - range 0x%08x < 0x%08x%s < 0x%08x\n",
      axis_idx, str_tag, v_min, coord_values[axis_idx], is_def, v_max)
  end

  coord_ptr = FFI::MemoryPointer.new(:long, num_axis)
  coord_ptr.write_array_of_long(coord_values)

  ft_err = FreeType::C.FT_Set_Var_Design_Coordinates(ft_face, num_axis, coord_ptr)
  if (ft_err)
    printf("FT_Set_Var_Design_Coodinates() error = %d\n", ft_err)
    # raise "FT_Set_Var_Design_Coordinates() failed"
  end

  coord_ptr_r = FFI::MemoryPointer.new(:long, num_axis)
  ft_err = FreeType::C.FT_Get_Var_Design_Coordinates(ft_face, num_axis, coord_ptr_r)
  raise "FT_Get_Var_Design_Coordinates() failed" unless ft_err == 0
  coord_values_r = coord_ptr_r.read_array_of_long(num_axis)

  num_axis.times do |axis_idx|
    printf("coord #%d: 0x%08x -> 0x%08x\n",
            axis_idx, coord_values[axis_idx], coord_values_r[axis_idx])
  end
end

# === SET PIXEL SIZE ===
ft_err = FreeType::C.FT_Set_Pixel_Sizes(ft_face, Opts.width, Opts.height)
raise "FT_Set_Pixel_Sizes() failed" unless ft_err == 0

ft_size = FT_SizeRec.new(ft_face[:size])

ft_metric = ft_size[:metrics]

# === RENDER GLYPH ===
if (Opts.gid == 0)
  Opts.gid = FreeType::C.FT_Get_Char_Index(ft_face, Opts.uhex)
end
ft_err = FreeType::C.FT_Load_Glyph( ft_face, Opts.gid, 8)
raise "FT_Load_Glyph() failed" unless ft_err == 0

ft_glyphslot_ptr = ft_face[:glyph]
ft_glyphslot = FT_GlyphSlotRec.new(ft_glyphslot_ptr)

puts("glyph format is " + [ft_glyphslot[:format]].pack("N").encode("us-ascii"))
if (ft_glyphslot[:format] == "outl".unpack("N*").first)
  puts("this glyph is outline")
end


ft_err = FreeType::C.FT_Render_Glyph(ft_glyphslot_ptr, 0)
raise "FT_Render_Glyph() failed" unless ft_err == 0
ft_bitmap = ft_glyphslot[:bitmap]

# === EXTRACT BITMAP DATA ===
glyph_width  = ft_bitmap[:width]
glyph_height = ft_bitmap[:rows]
glyph_advance_to_baseline  = [0, ft_glyphslot[:bitmap_top]].max
glyph_left_bearing = [0, ft_glyphslot[:bitmap_left]].max

ft_pixel_buffer_ptr = ft_bitmap[:buffer]
nbytes_row = ft_bitmap[:pitch]
nbytes_buffer = nbytes_row * glyph_height

arr_pixels = ft_pixel_buffer_ptr.read_bytes(nbytes_buffer).unpack("C*")

## === DUMP BITMAP ===
if (Opts.aa)
  (0...(Opts.height - glyph_advance_to_baseline)).to_a().each do |iy|
    puts(" " * (glyph_left_bearing + glyph_width))
  end

  (0...glyph_height).to_a().each do |iy|
    line = [ " " * glyph_left_bearing ]
    (0...glyph_width).to_a().each do |ix|
      pxl = arr_pixels[(iy * nbytes_row) + ix]
      if (pxl == nil)
        break
      elsif (pxl > 0)
        line << "#"
      else
        line << " "
      end
    end
    printf("%s\n", line.join(""))
  end

  (0...(glyph_advance_to_baseline - glyph_height)).to_a().each do |iy|
    puts(" " * (glyph_left_bearing + glyph_width))
  end


  baseline_y = 0
  bitmap_bottom = ft_glyphslot[:bitmap_top] - ft_bitmap[:rows]
  descender_px = ft_metric[:descender] >> 6

  space_under_baseline = bitmap_bottom - descender_px
  (0...space_under_baseline).to_a().each do |iy|
    puts(" " * (glyph_left_bearing + glyph_width))
  end

end

# === CREATE IMAGE ===
require 'rmagick'
magick_image = Magick::Image.new(Opts.width > 0 ? Opts.width : Opts.height, Opts.height)
magick_image.background_color = "white"
magick_glyph = Magick::Image.new(glyph_width, glyph_height)
magick_glyph.background_color = "white"
arr_pixels_16bit = arr_pixels.map{|v| v * 257}
magick_glyph.import_pixels(0, 0, glyph_width, glyph_height, 'I', arr_pixels_16bit, Magick::ShortPixel)
magick_glyph = magick_glyph.negate
magick_image = magick_image.composite(magick_glyph, Magick::CenterGravity, Magick::CopyCompositeOp)

# === DISTORT ===
if (Opts.include?("auto-seed") || Opts["seed"] == nil)
  require "digest/xxhash"
  seed_tokens = []
  seed_tokens << ("font=" + Opts.font.split("/").last.gsub(/\.[0-9a-zA-Z]{3,4}$/, ""))
  seed_tokens << ("gid=" + Opts.gid.to_s())
  seed_tokens << ("mesh=" + Opts.mesh.to_s())
  seed_tokens << ("strength=" + Opts.strength.map{|v| v.to_s()}.join(":"))
  seed_tokens << ("noise-sub=" + Opts.noise_sub.map{|v| v.to_s()}.join(":"))
  seed_tokens << ("noise-add=" + Opts.noise_add.map{|v| v.to_s()}.join(":"))
  seed_tokens << ("erode-dilate=" + Opts.erode_dilate.map{|v| v.to_s()}.join(":"))
  seed_tokens << ("aspect-range-x=" + Opts.aspect_range_x.to_s()) if (Opts.aspect_range_x != nil)
  seed_tokens << ("aspect-range-y=" + Opts.aspect_range_y.to_s()) if (Opts.aspect_range_y != nil)
  p seed_tokens
  hd128 = Digest::XXH3_128bits.hexdigest(seed_tokens.join("\t"))
  STDERR.printf("# seed=" + hd128 + "\n")
  if (Opts.output.include?("%S"))
    Opts["output"] = Opts.output.gsub("%S", XorShift128p_u32.enc64(hd128)[0..21])
  end
  Opts["seed"] = hd128
end

prng = XorShift128p_u32.new(Opts.a, Opts.b, Opts.c, Opts.seed)
# p prng
points1 = []
points2 = []
(1..Opts.mesh).each do |iy|
  src_y = magick_image.rows * iy / Opts.mesh
  (1..Opts.mesh).each do |ix|
    src_x = magick_image.columns * ix / Opts.mesh

    # (4 x 5bit) + 4bit = 24bit for single random vector
    # |----| dx1 | dy1 | dx2 | dy2 |
    # |0123|45678|9abcd|ef012|34567|

    rnd32 = prng.next()
    Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
    rnd32 = rnd32 >> 4 # discard 4 LSB for bad-equibilium
    dx1 = ((rnd32 & 0x1F) - 0xF) * Opts.strength.first / 0x1F
    rnd32 = rnd32 >> 5
    dy1 = ((rnd32 & 0x1F) - 0xF) * Opts.strength.first / 0x1F
    rnd32 = rnd32 >> 5
    dx2 = ((rnd32 & 0x1F) - 0xF) * Opts.strength.last / 0x1F
    rnd32 = rnd32 >> 5
    dy2 = ((rnd32 & 0x1F) - 0xF) * Opts.strength.last / 0x1F

    dst1_x = src_x + dx1
    dst1_y = src_y + dy1
    dst2_x = src_x + dx2
    dst2_y = src_y + dy2
    if (Opts.log)
      Opts.log.printf("distortion @%03d,%03d: img1(%s%02d,%s%02d), img2(%s%02d,%s%02d)\n",
                      src_x, src_y,
                      (dx1 < 0) ? "+" : "-", dx1.abs(),
                      (dy1 < 0) ? "+" : "-", dy1.abs(),
                      (dx2 < 0) ? "+" : "-", dx2.abs(),
                      (dy2 < 0) ? "+" : "-", dy2.abs()
                     )
    end
    points1 << src_x
    points1 << src_y
    points2 << src_x
    points2 << src_y
    points1 << dst1_x
    points1 << dst1_y
    points2 << dst2_x
    points2 << dst2_y
  end
end

  magick_image_distorted1 = magick_image
if (Opts.erode_dilate.first < 0)
  magick_image_distorted1 = magick_image.morphology(
    Magick::ErodeMorphology, Opts.erode_dilate.first.abs, "Diamond")
elsif (Opts.erode_dilate.first > 0)
  magick_image_distorted1 = magick_image.morphology(
    Magick::DilateMorphology, Opts.erode_dilate.first.abs, "Diamond")
end
magick_image_distorted1 = magick_image_distorted1.distort(Magick::ShepardsDistortion, points1, true)

magick_image_distorted2 = magick_image
if (Opts.erode_dilate.last < 0)
  magick_image_distorted2 = magick_image.morphology(
    Magick::ErodeMorphology, Opts.erode_dilate.last.abs, "Diamond")
elsif (Opts.erode_dilate.last > 0)
  magick_image_distorted2 = magick_image.morphology(
    Magick::DilateMorphology, Opts.erode_dilate.last.abs, "Diamond")
end
magick_image_distorted2 = magick_image_distorted2.distort(Magick::ShepardsDistortion, points2, true)

# === ASPECT RANDOMIZE ===
def get_random_from_str_range(s, rnd_8bit)
  vs = s.split("..").map{|v| v.to_f()}
  r = (vs[0])..(vs[1])
  r_min = vs[0]
  r_diff = vs[1] - vs[0]
  v = r_min + ((r_diff * rnd_8bit) / 0xFF)
  return v
end

def apply_aspect_noise(img, prng)
  return img if (Opts.aspect_range_x == nil && Opts.aspect_range_y == nil)

  rnd32 = prng.next()
  Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
  rnd28 = rnd32.next() >> 4
  rnd8x = rnd28 & 0xFF
  rnd8y = (rnd28 >> 8) & 0xFF

  ax = Opts.aspect_range_x ? get_random_from_str_range(Opts.aspect_range_x, rnd8x) : 1
  ay = Opts.aspect_range_y ? get_random_from_str_range(Opts.aspect_range_y, rnd8y) : 1

  width_old  = img.columns
  height_old = img.rows
  width_new  = (ax * img.columns).to_i()
  height_new = (ay * img.rows).to_i()

  img_resized = img.resize(width_new, height_new)
  img.erase!
  img.background_color = "white"
  if Opts.fill_extent
    dx = img.columns - width_new
    dy = img.rows - height_new
    draw = Magick::Draw.new()
    rnd32 = prng.next()
    Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
    r = (rnd32 >> 4) & 0x3
    case r
    when 0 then
      gr = Magick::NorthEastGravity
      draw.rectangle(0, 0,          dx, height_old) # vertical line at left
      draw.rectangle(0, height_new, width_old, height_old) # horizontal line at bottom
    when 1 then
      gr = Magick::NorthWestGravity
      draw.rectangle(width_new, 0,  width_old, height_old) # vertical line at right
      draw.rectangle(0, height_new, width_old, height_old) # horizontal line at bottom
    when 2 then
      gr = Magick::SouthEastGravity
      draw.rectangle(0, 0,          dx, height_old) # vertical line at left
      draw.rectangle(0, 0,          width_old, dy) # horizontal line at top
    when 3 then
      gr = Magick::SouthWestGravity
      draw.rectangle(width_new, 0,  width_old, height_old) # vertical line at right
      draw.rectangle(0, 0,          width_old, dy) # horizontal line at top
    end
    # p gr
    img = img.composite(img_resized, gr, Magick::CopyCompositeOp)
    draw.draw(img)
    img.write("fill-extent.png")
  else
    img = img.composite(img_resized, Magick::CenterGravity, Magick::CopyCompositeOp)
  end
  return img
end

if (Opts.apply_aspect.downcase().include?("g"))
  magick_image_distorted1 = apply_aspect_noise(magick_image_distorted1, prng)
end
if (Opts.apply_aspect.downcase().include?("r"))
  magick_image_distorted2 = apply_aspect_noise(magick_image_distorted2, prng)
end

# === RANDOM MASK IMAGES ===

def gen_random_mask(img_width, img_height, stroke_color, stroke_width, number_strokes, prng)
  canvas = Magick::Image.new(img_width, img_height) {|options| options.background_color = "none"}
  draw = Magick::Draw.new()
  draw.stroke(stroke_color)
  draw.stroke_width(stroke_width)
  draw.stroke_linecap("round")
  (0...number_strokes).each do |i|
    rnd32 = prng.next()
    Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
    x = (rnd32 >> 4) % img_width
    rnd32 = prng.next()
    Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
    y = (rnd32 >> 4) % img_height
    rnd32 = prng.next()
    Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
    dx = ((rnd32 >> 4) % (img_width / 4))  - (img_width  /8)
    rnd32 = prng.next()
    Opts.log.printf("prng.next(): 0x%08x\n", rnd32) if (Opts.log)
    dy = ((rnd32 >> 4) % (img_height / 4)) - (img_height /8)
    draw.line(x, y, x + dx, y + dy)
    if (Opts.log)
      Opts.log.printf("  vector #%02d: (%03d,%03d) -> (%03d,%03d)\n", i, x, y, x+dx, y+dy)
    end
  end
  draw.draw(canvas)
  return canvas
end

# === SAVE IMAGE ===
img_orig = magick_image # .transparent("white")
img_dist1 = magick_image_distorted1 # .transparent("white")
img_dist2 = magick_image_distorted2 # .transparent("white")

Opts.log.puts("image1 noise-sub") if (Opts.log)
mask_sub1 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "white", img_orig.rows / 20, Opts.noise_sub.first,
                            prng)
Opts.log.puts("image1 noise-add") if (Opts.log)
mask_add1 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "black", img_orig.rows / 20, Opts.noise_add.first,
                            prng)

Opts.log.puts("image2 noise-sub") if (Opts.log)
mask_sub2 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "white", img_orig.rows / 20, Opts.noise_sub.last,
                            prng)
Opts.log.puts("image2 noise-add") if (Opts.log)
mask_add2 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "black", img_orig.rows / 20, Opts.noise_add.last,
                            prng)

img_dist1 = img_dist1.composite(mask_sub1, 0, 0, Magick::SrcOverCompositeOp)
                     .composite(mask_add1, 0, 0, Magick::SrcOverCompositeOp)
img_dist2 = img_dist2.composite(mask_sub2, 0, 0, Magick::SrcOverCompositeOp)
                     .composite(mask_add2, 0, 0, Magick::SrcOverCompositeOp)

img_dist1_q = img_dist1.quantize(2, Magick::GRAYColorspace)
img_dist2_q = img_dist2.quantize(2, Magick::GRAYColorspace)
img_dist1.destroy!
img_dist2.destroy!
img_dist1 = img_dist1_q
img_dist2 = img_dist2_q

img_mixed = Magick::Image.new(img_orig.columns, img_orig.rows)

def decr(v, lmt, s = 2.0)
  if (v < lmt)
    return [lmt - ((lmt - v) * s), 0].max
  else
    return v
  end
end


pxls_dist1 = img_dist1.get_pixels(0, 0, img_dist1.columns, img_dist1.rows)
pxls_dist2 = img_dist2.get_pixels(0, 0, img_dist2.columns, img_dist2.rows)
pxls_mixed = pxls_dist1.zip(pxls_dist2).map{|pxl_dist1, pxl_dist2|
  fi_dist1 = pxl_dist1.intensity * 1.0 / Magick::QuantumRange
  fi_dist2 = pxl_dist2.intensity * 1.0 / Magick::QuantumRange

  if (fi_dist1 < 1 || fi_dist2 < 1)
    fi_dist1 = fi_dist1 * 0.8
    fi_dist2 = fi_dist2 * 0.7
  end

  r =  fi_dist1 * Magick::QuantumRange
  g =  fi_dist2 * Magick::QuantumRange
  b =  fi_dist1 * fi_dist2 * Magick::QuantumRange
  pxl_mixed = Magick::Pixel.new(r, g, b)
  pxl_mixed
}
img_mixed.store_pixels(0, 0, img_mixed.columns, img_mixed.rows, pxls_mixed)

fho = File::open(Opts.output, "wb")
img_mixed.format = "png"
img_mixed.write(fho)
fho.close()

puts "Saved rasterized glyph ##{Opts.gid} to #{Opts.output}"
puts "#{prng.count} random number is consumed"
