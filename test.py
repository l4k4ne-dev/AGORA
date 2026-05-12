def factorial(n):
    if n == 0:
        return 1
    else:
        return n * factorial(n-1)

result = factorial(10)
print(f"The factorial of 10 is: {result}")
