EMACS ?= emacs
ELS    = countdown-modeline.el
TESTS  = countdown-modeline-tests.el

.PHONY: all compile test clean

all: compile test

compile:
	$(EMACS) -Q --batch -L . \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $(ELS)

test:
	$(EMACS) -Q --batch -L . -l $(TESTS) -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc
