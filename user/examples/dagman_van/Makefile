all: random.condor half.condor sum.condor

random.condor: random.c
	gcc -o random.condor random.c

half.condor: half.c
	gcc -o half.condor half.c

sum.condor: sum.c
	gcc -o sum.condor sum.c

clean:
	rm -f *.out *.err *.log diamond.dag.* *.condor *~ 
