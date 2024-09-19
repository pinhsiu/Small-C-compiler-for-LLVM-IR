all:
	java -cp ./antlr-3.5.3-complete-no-st3.jar org.antlr.Tool myCompiler.g
	javac -cp ./antlr-3.5.3-complete-no-st3.jar:. myCompiler_test.java

test1:
	make 
	java -cp ./antlr-3.5.3-complete-no-st3.jar:. myCompiler_test test1.c > test1.ll
	lli test1.ll
	make clean

test2:
	make 
	java -cp ./antlr-3.5.3-complete-no-st3.jar:. myCompiler_test test2.c > test2.ll
	lli test2.ll
	make clean

test3:
	make 
	java -cp ./antlr-3.5.3-complete-no-st3.jar:. myCompiler_test test3.c > test3.ll
	lli test3.ll
	make clean

clean:
	rm -rf myCompilerLexer.java myCompilerParser.java myCompiler.tokens *.class