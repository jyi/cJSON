CJSON_OBJ = cJSON.o
UTILS_OBJ = cJSON_Utils.o
CJSON_OBJ_KLEE = cJSON.klee.o
UTILS_OBJ_KLEE = cJSON_Utils.klee.o
CJSON_LIBNAME = libcjson
UTILS_LIBNAME = libcjson_utils
CJSON_TEST = cJSON_test

CJSON_TEST_SRC = cJSON.c test.c

LDLIBS = -lm

LIBVERSION = 1.7.12
CJSON_SOVERSION = 1
UTILS_SOVERSION = 1

CJSON_SO_LDFLAG=-Wl,-soname=$(CJSON_LIBNAME).so.$(CJSON_SOVERSION)
UTILS_SO_LDFLAG=-Wl,-soname=$(UTILS_LIBNAME).so.$(UTILS_SOVERSION)

PREFIX ?= /usr/local
INCLUDE_PATH ?= include/cjson
LIBRARY_PATH ?= lib

INSTALL_INCLUDE_PATH = $(DESTDIR)$(PREFIX)/$(INCLUDE_PATH)
INSTALL_LIBRARY_PATH = $(DESTDIR)$(PREFIX)/$(LIBRARY_PATH)

INSTALL ?= cp -a

AR_KLEE = llvm-ar
CC_KLEE = llvm-gcc

# validate gcc version for use fstack-protector-strong
MIN_GCC_VERSION = "4.9"
GCC_VERSION := "`$(CC) -dumpversion`"
IS_GCC_ABOVE_MIN_VERSION := $(shell expr "$(GCC_VERSION)" ">=" "$(MIN_GCC_VERSION)")
ifeq "$(IS_GCC_ABOVE_MIN_VERSION)" "1"
    CFLAGS += -fstack-protector-strong
else
    CFLAGS += -fstack-protector
endif

R_CFLAGS = -fPIC -std=c89 -pedantic -Wall -Werror -Wstrict-prototypes -Wwrite-strings -Wshadow -Winit-self -Wcast-align -Wformat=2 -Wmissing-prototypes -Wstrict-overflow=2 -Wcast-qual -Wc++-compat -Wundef -Wswitch-default -Wconversion $(CFLAGS)

R_CFLAGS_KLEE = -fPIC -std=c89 -pedantic -Wall -Werror -Wstrict-prototypes -Wwrite-strings -Wshadow -Winit-self -Wcast-align -Wformat=2 -Wmissing-prototypes -Wstrict-overflow=2 -Wc++-compat -Wundef -Wswitch-default -fPIC

uname := $(shell sh -c 'uname -s 2>/dev/null || echo false')

#library file extensions
SHARED = so
STATIC = a

## create dynamic (shared) library on Darwin (base OS for MacOSX and IOS)
ifeq (Darwin, $(uname))
	SHARED = dylib
	CJSON_SO_LDFLAG = ""
	UTILS_SO_LDFLAG = ""
endif

#cJSON library names
CJSON_SHARED = $(CJSON_LIBNAME).$(SHARED)
CJSON_SHARED_VERSION = $(CJSON_LIBNAME).$(SHARED).$(LIBVERSION)
CJSON_SHARED_SO = $(CJSON_LIBNAME).$(SHARED).$(CJSON_SOVERSION)
CJSON_STATIC = $(CJSON_LIBNAME).$(STATIC)
CJSON_STATIC_KLEE = $(CJSON_LIBNAME).klee.$(STATIC)

#cJSON_Utils library names
UTILS_SHARED = $(UTILS_LIBNAME).$(SHARED)
UTILS_SHARED_VERSION = $(UTILS_LIBNAME).$(SHARED).$(LIBVERSION)
UTILS_SHARED_SO = $(UTILS_LIBNAME).$(SHARED).$(UTILS_SOVERSION)
UTILS_STATIC = $(UTILS_LIBNAME).$(STATIC)
UTILS_STATIC_KLEE = $(UTILS_LIBNAME).klee.$(STATIC)

SHARED_CMD = $(CC) -shared -o

.PHONY: all shared static tests clean install

all: shared static tests

shared: $(CJSON_SHARED) $(UTILS_SHARED)

static: $(CJSON_STATIC) $(CJSON_STATIC_KLEE) $(UTILS_STATIC) $(UTILS_STATIC_KLEE)

tests: $(CJSON_TEST)

test: tests
	./$(CJSON_TEST)

%.o : %.c
	$(CC) -c $(R_CFLAGS) $<

%.klee.o : %.c
	$(CC_KLEE) -g -O0 --emit-llvm -c $(R_CFLAGS_KLEE) -o $@ $<

#tests
#cJSON
$(CJSON_TEST): $(CJSON_TEST_SRC) cJSON.h
	$(CC) $(R_CFLAGS) $(CJSON_TEST_SRC)  -o $@ $(LDLIBS) -I.

#static libraries
#cJSON
$(CJSON_STATIC): $(CJSON_OBJ)
	$(AR) rcs $@ $<
#cJSON.klee
$(CJSON_STATIC_KLEE): $(CJSON_OBJ_KLEE)
	$(AR_KLEE) rcs $@ $<
#cJSON_Utils
$(UTILS_STATIC): $(UTILS_OBJ)
	$(AR) rcs $@ $<
#cJSON_Utils.klee
$(UTILS_STATIC_KLEE): $(UTILS_OBJ_KLEE)
	$(AR_KLEE) rcs $@ $<

#shared libraries .so.1.0.0
#cJSON
$(CJSON_SHARED_VERSION): $(CJSON_OBJ)
	$(CC) -shared -o $@ $< $(CJSON_SO_LDFLAG) $(LDFLAGS)
#cJSON_Utils
$(UTILS_SHARED_VERSION): $(UTILS_OBJ)
	$(CC) -shared -o $@ $< $(UTILS_SO_LDFLAG) $(LDFLAGS)

#objects
#cJSON
$(CJSON_OBJ): cJSON.c cJSON.h
#cJSON_Utils
$(UTILS_OBJ): cJSON_Utils.c cJSON_Utils.h


#links .so -> .so.1 -> .so.1.0.0
#cJSON
$(CJSON_SHARED_SO): $(CJSON_SHARED_VERSION)
	ln -s $(CJSON_SHARED_VERSION) $(CJSON_SHARED_SO)
$(CJSON_SHARED): $(CJSON_SHARED_SO)
	ln -s $(CJSON_SHARED_SO) $(CJSON_SHARED)
#cJSON_Utils
$(UTILS_SHARED_SO): $(UTILS_SHARED_VERSION)
	ln -s $(UTILS_SHARED_VERSION) $(UTILS_SHARED_SO)
$(UTILS_SHARED): $(UTILS_SHARED_SO)
	ln -s $(UTILS_SHARED_SO) $(UTILS_SHARED)

#install
#cJSON
install-cjson:
	mkdir -p $(INSTALL_LIBRARY_PATH) $(INSTALL_INCLUDE_PATH)
	$(INSTALL) cJSON.h $(INSTALL_INCLUDE_PATH)
	$(INSTALL) $(CJSON_SHARED) $(CJSON_SHARED_SO) $(CJSON_SHARED_VERSION) $(INSTALL_LIBRARY_PATH)
#cJSON_Utils
install-utils: install-cjson
	$(INSTALL) cJSON_Utils.h $(INSTALL_INCLUDE_PATH)
	$(INSTALL) $(UTILS_SHARED) $(UTILS_SHARED_SO) $(UTILS_SHARED_VERSION) $(INSTALL_LIBRARY_PATH)

install: install-cjson install-utils

#uninstall
#cJSON
uninstall-cjson: uninstall-utils
	$(RM) $(INSTALL_LIBRARY_PATH)/$(CJSON_SHARED)
	$(RM) $(INSTALL_LIBRARY_PATH)/$(CJSON_SHARED_VERSION)
	$(RM) $(INSTALL_LIBRARY_PATH)/$(CJSON_SHARED_SO)
	rmdir $(INSTALL_LIBRARY_PATH)
	$(RM) $(INSTALL_INCLUDE_PATH)/cJSON.h
	rmdir $(INSTALL_INCLUDE_PATH)
#cJSON_Utils
uninstall-utils:
	$(RM) $(INSTALL_LIBRARY_PATH)/$(UTILS_SHARED)
	$(RM) $(INSTALL_LIBRARY_PATH)/$(UTILS_SHARED_VERSION)
	$(RM) $(INSTALL_LIBRARY_PATH)/$(UTILS_SHARED_SO)
	$(RM) $(INSTALL_INCLUDE_PATH)/cJSON_Utils.h

uninstall: uninstall-utils uninstall-cjson

clean:
	$(RM) $(CJSON_OBJ) $(UTILS_OBJ) $(CJSON_OBJ_KLEE) $(UTILS_OBJ_KLEE) #delete object files
	$(RM) $(CJSON_SHARED) $(CJSON_SHARED_VERSION) $(CJSON_SHARED_SO) $(CJSON_STATIC) $(CJSON_STATIC_KLEE) #delete cJSON
	$(RM) $(UTILS_SHARED) $(UTILS_SHARED_VERSION) $(UTILS_SHARED_SO) $(UTILS_STATIC) #delete cJSON_Utils
	$(RM) $(CJSON_TEST)  #delete test
