# Building and testing:
#   make             build the tools piq2py, py2png and piq2png into bin/
#   make test        all the tests
#   make part1       only Part 1's tests (names and keywords)
#   ...
#   make part10      only Part 10's tests (the whole pipeline)
#   make clean       remove bin/, build files, and generated Python/pictures
#
# To run the tests for a single step, for example Step 3.2:
#   runghc -itest test/Spec.hs --match "Step 3.2"

TOOLS   = bin/piq2py bin/py2png bin/piq2png
SOURCES = $(wildcard *.hs)
SPEC    = runghc -itest test/Spec.hs

all: $(TOOLS)

bin/%: %.hs $(SOURCES)
	@mkdir -p bin build/$*
	ghc -O -outputdir build/$* -o $@ $<

test:
	$(SPEC)

part1:
	$(SPEC) --match "Part 1:"
part2:
	$(SPEC) --match "Part 2:"
part3:
	$(SPEC) --match "Part 3:"
part4:
	$(SPEC) --match "Part 4:"
part5:
	$(SPEC) --match "Part 5:"
part6:
	$(SPEC) --match "Part 6:"
part7:
	$(SPEC) --match "Part 7:"
part8:
	$(SPEC) --match "Part 8:"
part9:
	$(SPEC) --match "Part 9:"
part10:
	$(SPEC) --match "Part 10:"

clean:
	rm -rf bin build *.hi *.o test/*.hi test/*.o python/__pycache__
	find programs python -name '*.png' -delete
	find programs -name '*.py' -delete
	find python -name '*.py' ! -name plotter_runtime.py ! -name nextdraw_backend.py ! -name mock_nextdraw.py -delete

.PHONY: all test part1 part2 part3 part4 part5 part6 part7 part8 part9 part10 clean
