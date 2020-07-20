# Run as many jobs as possible as long as the load average is less than 2.6
MAKEFLAGS   += --jobs --max-load 2.6

# Setup variables required for crafter operations.
OUTDIR      := $(CURDIR)/out
PLATFORMDIR := $(CURDIR)/platforms
CRAFTERDIR  := $(CURDIR)/..
MODULEDIR   := $(CURDIR)/modules

# Include main crafter makefile.
include $(CRAFTERDIR)/core/bootstrap.mk
