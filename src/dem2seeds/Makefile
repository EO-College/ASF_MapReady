CFLAGS += $(HDF5_CFLAGS)
CFLAGS += $(GEOTIFF_CFLAGS)
CFLAGS += $(HDF5_CFLAGS)
# Makefile for dem2seeds

include ../../make_support/system_rules

LIBS  = \
	$(LIBDIR)/asf_meta.a \
	$(GSL_LIBS) \
	$(LIBDIR)/libasf_proj.a \
	$(LIBDIR)/asf.a \
	$(PROJ_LIBS) \
	$(XML_LIBS) \
	-lm

OBJS = dem2seeds.o

all: dem2seeds
	rm *.o

dem2seeds: $(OBJS)
	$(CC) $(CFLAGS) -o dem2seeds $(OBJS) $(LIBS) $(LDFLAGS)
	mv dem2seeds$(BIN_POSTFIX) $(BINDIR)
	cp dem2seeds.1 ../../man/cat1

clean:
	rm -f core $(OBJS) *.o
