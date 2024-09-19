; === prologue ====
@t5 = constant [13 x i8] c"Hello World\0A\00"
declare dso_local i32 @printf(i8*, ...)

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
%t1 = sub nsw i32 0, 8
%t2 = sdiv i32 %t1, 2
%t3 = add nsw i32 %t2, 1
store i32 %t3, i32* %t0
%t4 = load i32, i32* %t0
call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @t5, i32 0, i32 0))

; === epilogue ===
ret i32 0
}
