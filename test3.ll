; === prologue ====
@t12 = constant [18 x i8] c"a is equal to b.\0A\00"
@t10 = constant [22 x i8] c"a is smaller than b.\0A\00"
@t5 = constant [21 x i8] c"a is bigger than b.\0A\00"
declare dso_local i32 @printf(i8*, ...)

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
%t1 = alloca i32, align 4
store i32 5, i32* %t1
store i32 7, i32* %t0
%t2 = load i32, i32* %t1
%t3 = load i32, i32* %t0
%t4 = icmp sgt i32 %t2, %t3
br i1 %t4, label %L1, label %L2
L1:
call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([21 x i8], [21 x i8]* @t5, i32 0, i32 0))
br label %L3
L2:
%t7 = load i32, i32* %t1
%t8 = load i32, i32* %t0
%t9 = icmp slt i32 %t7, %t8
br i1 %t9, label %L4, label %L5
L4:
call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([22 x i8], [22 x i8]* @t10, i32 0, i32 0))
br label %L3
L5:
call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @t12, i32 0, i32 0))
br label %L3
L3:

; === epilogue ===
ret i32 0
}
