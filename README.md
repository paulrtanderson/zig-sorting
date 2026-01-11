Possible `stable` \*`in place` sorting algorithm implementations in Zig.


\*`in place` in this context means that it is possible to sort any realistic data set without dynamic memory allocation. for example, some of the algorithms here may require O(log n) auxiliary scratch space, which is acceptable as we can allocate [64]T and that would be enough to sort 2^64 elements, which is more than realistic for any computer.

** The problem
Zig requires a general purpose stable in place sorting algorithm for the std lib, the main problem here is the general purpose requirement, as currently the way they achieve this is to provide a context arguement which acts as a pseudo closure, in this context the user provides a LessThan function that is used to compare elements, so far so good, however it also requires a Swap function, which is a problem for algorithms which use auxiliary or scratch space, as they need to be able to copy elements into and out of this space, which is not possible with just a Swap function.

To solve this problem we need sorting algorithms that do not require copying elements into and out of auxiliary space, which is a very limiting requirement, as most stable in place sorting algorithms use such techniques, or we need to modify the API to allow for copying elements.

Andrew Kelley has expressed interest in modifying the API as performance is of a higher concern than minimising api complexity.

How would we do this?

we could provide a getter and setter function in the context, this would allow algorithms to copy elements into and out of auxiliary space, however the performance impact is of this needs investigation. - Perhaps we could allow an optional swap function which we check with @hasDecl and use that for in place swapping when available, and fall back to getter/setter when we need to copy elements to/from auxiliary space.

Another option to consider is just using the wikisort variant with no scratch space when we need to pass in a context and defaulting to the scratch space version when we only need a less than function, [this PR](https...) implements such a variant but also makes it default when passing in a context, which is probably not ideal.

getter and setter api:

```zig
pub fn sort(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) void {
    const Context = struct {
        items: []T,
				scratch: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
        }

				pub fn get(ctx: @This(), index: usize) T {
						return ctx.items[index];
				}

				pub fn set(ctx: @This(), index: usize, value: T) void {
						ctx.items[index] = value;
				}

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            return mem.swap(T, &ctx.items[a], &ctx.items[b]);
        }
    };
		var scratch: [64]T = undefined;
    sortContextAux(0, items.len, Context{ .items = items, .scratch = &scratch, .sub_ctx = context });
}


pub fn sortContext
```




1. Logsort
  - QuickSort variant
  - O(n log n) average case time complexity (worst case depends on partitioning scheme)
  - O(log n) space complexity (in practice a smaller constant factor than Wikisort)
  - MIT License
  - [Github repo](https://github.com/aphitorite/Logsort)
  - [Wiki entry](https://sortingalgos.miraheze.org/wiki/Logsort)
 
2. Wikisort
  - Block Merge Sort variant
  - O(n log n) time complexity
  - O(1) space complexity (512 element scratch space) (this scratch space has been notes to be a stack overflow risk for Tigerbeetle)
  - MIT License
  - current std.sort implementation is based on this algorithm
	- not as fast as the other algorithms here, and scratch space is in practice larger than the O(log n) of other algorithms
  - [Github repo](https://github.com/BonzaiThePenguin/WikiSort)
	- [Wiki entry](https://sortingalgos.miraheze.org/wiki/WikiSort)