; === prologue ====
declare dso_local i32 @printf(i8*, ...)

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
%t1 = alloca i32, align 4
%t2 = load i32, i32* %t0
%t3 = sub nsw i32 100, 1
%t4 = mul nsw i32 2, %t3
%t5 = add nsw i32 %t2, %t4
store i32 %t5, i32* %t1
%t6 = load i32, i32* %t1

; === epilogue ===
ret i32 0
}
