CFLAGS += $(HDF5_CFLAGS)
CFLAGS += $(GEOTIFF_CFLAGS)
CFLAGS += $(HDF5_CFLAGS)

include ../../make_support/system_rules

TARGET = llh2ls
OBJS  = $(TARGET).o

REQUIRED_LIBS = \
	$(LIBDIR)/libasf_sar.a \
	$(LIBDIR)/libasf_raster.a \
	$(LIBDIR)/asf_meta.a \
	$(LIBDIR)/libasf_proj.a \
        $(LIBDIR)/asf.a \
	$(XML_LIBS) \
	$(GLIB_LIBS) \
	$(GSL_LIBS) \
	$(PROJ_LIBS) \
	$(JPEG_LIBS) \
	$(ZLIB_LIBS) \
	-lm

CEDAR_LIBS = $(LIBDIR)/asf_las.a
LIBS = \
	$(shell \
	if [ `hostname` = "cedar" ] ; then \
		echo $(REQUIRED_LIBS) $(CEDAR_LIBS) ; \
	else \
		echo $(REQUIRED_LIBS) ; \
	fi \
	)

all: $(TARGET) clean

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(TARGET) $(OBJS) $(LIBS)
	mv $(TARGET)$(BIN_POSTFIX) $(BINDIR)

clean:
	rm -f $(OBJS)
