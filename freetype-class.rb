require 'freetype'
require 'freetype/c'
class FT_Vector < FFI::Struct
  layout(
    :x, :long,
    :y, :long
  )
end
class FT_BBox < FFI::Struct
  layout(
    :xMin, :long,
    :yMin, :long,
    :xMax, :long,
    :yMax, :long
  )
end
class FT_Glyph_Metrics < FFI::Struct
  layout(
    :width, :long,
    :height, :long,

    :horiBearingX, :long,
    :horiBearingY, :long,
    :horiAdvance,  :long,

    :vertBearingX, :long,
    :vertBearingY, :long,
    :vertAdvance,  :long
  )
end
class FT_Bitmap < FFI::Struct
  layout(
    :rows,         :uint,
    :width,        :uint,
    :pitch,        :int,
    :buffer,       :pointer,
    :num_grays,    :short,
    :pixel_mode,   :uchar,
    :palette_mode, :uchar,
    :palette,      :pointer
  )
end
class FT_GlyphSlotRec < FFI::Struct
  layout(
    :library,     :pointer,
    :face,        :pointer,
    :next,        :pointer,
    :glyph_index, :uint,
    :generic,      [:pointer, 2],

    :metrics,           FT_Glyph_Metrics,
    :linearHoriAdvance, :long,
    :linearVertAdvance, :long,
    :advance,           FT_Vector,

    :format,      :uint, # 4-letter

    :bitmap,      FT_Bitmap,
    :bitmap_left, :int,
    :bitmap_top,  :int
  )
end
class FT_Size_Metrics < FFI::Struct
  layout(
    :x_ppem,       :ushort,
    :y_ppem,       :ushort,
    :x_scale,      :long,
    :y_scale,      :long,
    :ascender,     :long,
    :descender,    :long,
    :height,       :long,
    :max_advance,  :long
  )
end
class FT_SizeRec < FFI::Struct
  layout(
    :face, :pointer,
    :generic, [:pointer, 2],
    :metrics, FT_Size_Metrics
  )
end
class FT_FaceRec < FFI::Struct
  layout(
    :num_faces,   :long,
    :face_index,  :long,

    :face_flags,  :long,
    :style_flags, :long,

    :num_glyphs,  :long,

    :family_name, :pointer,
    :style_name,  :pointer,

    :num_fixed_sizes, :int,
    :available_sizes, :pointer,

    :num_charmaps, :int,
    :charmaps,     :pointer,

    :generic,      [:pointer, 2],

    :bbox,         FT_BBox,
    :units_per_EM, :ushort,
    :ascender,     :short,
    :descender,    :short,
    :height,       :short,

    :max_advance_width,  :short,
    :max_advance_height, :short,

    :underline_position,  :short,
    :underline_thickness, :short,

    :glyph,        :pointer,
    :size,         :pointer
  )
end

module FreeType::C
  extend FFI::Library
  ffi_lib "freetype"

  attach_function :FT_Load_Glyph, [:pointer, :uint, :int], :int
  attach_function :FT_Set_Pixel_Sizes, [:pointer, :uint, :uint], :int
  attach_function :FT_Render_Glyph, [:pointer, :int], :int
end
