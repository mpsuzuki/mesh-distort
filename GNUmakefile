FT_CFLAGS = `pkg-config --cflags freetype2`
FT_LIBS = `pkg-config --libs freetype2`
CFLAGS = $(FT_CFLAGS) -g3 -ggdb -O0
LDFLAGS = $(FT_LIBS)

all: ft2aa.exe test-variable.exe

ft2aa.exe: ft2aa.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

test-variable.exe: test-variable.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
