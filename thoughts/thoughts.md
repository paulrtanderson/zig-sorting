Possible `stable` \*`in place` sorting algorithm implementations in Zig.


\*`in place` in this context means that it is possible to sort any realistic data set without dynamic memory allocation. for example, some of the algorithms here may require O(log n) auxiliary scratch space, which is acceptable as we can allocate [64]T and that would be enough to sort 2^64 elements, which is more than realistic for any computer. Though as noted below truely in place algorithms are very useful.

** The problem
Zig requires a general purpose stable in place sorting algorithm for the std lib, the main problem here is the general purpose requirement, as currently the way they achieve this is to provide a context arguement which acts as a pseudo closure, in this context the user provides a LessThan function that is used to compare elements, so far so good, however it also requires a Swap function, which is a problem for algorithms which use auxiliary or scratch space, as they need to be able to copy elements into and out of this space, which is not possible with just a Swap function.

To solve this problem we need sorting algorithms that do not require copying elements into and out of auxiliary space, which is a very limiting requirement, as most stable in place sorting algorithms use such techniques, or we need to modify the API to allow for copying elements.

Andrew Kelley has expressed interest in modifying the API as performance is of a higher concern than minimising api complexity.

How would we do this?

we could provide a getter and setter function in the context, this would allow algorithms to copy elements into and out of auxiliary space, however the performance impact is of this needs investigation. - Perhaps we could allow an optional swap function which we check with @hasDecl and use that for in place swapping when available, and fall back to getter/setter when we need to copy elements to/from auxiliary space.

Thinking about this more, sorts that use auxiliary space might not work for the general context variants, for example if we use parallel arrays such as in stdlib MultiArrayList, the user is going to have to provide getter/setter/swap functions that know how to handle multiple arrays, which is going to be very inconvenient, in fact it is impossible to implement such a sort with only static knowledge of the data structure, as the number of arrays is dynamic.

Thus likely the only viable algorithm for the general context variant is one that does not require any auxiliary space, such as sayhisort.

actually actually it could still work for auxiliary space sorts if we provide a copyFromScratch and copyToScratch functions in the context, this would allow the user to implement these functions to handle multiple arrays, however this is getting quite complex. The user would have to implement 4 functions: lessThan, swap, copyToScratch, copyFromScratch, their implementation would have to be quite specific to the data structure being sorted, for example for MultiArrayList the copyToScratch function the scratch space would have to be either a multi array itself, or a struct containing multiple arrays, and the copy functions would have to copy all the relevant elements to and from the scratch space.

perhaps the scratch versions could have an api something like this?

```zig
const std = @import("std");
const mem = std.mem;

pub fn sort(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), T, T) bool,
) void {
    var scratch: [64]T = undefined;
    sortAux(T, items, context, lessThanFn, &scratch);
}

pub fn sortAux(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), T, T) bool,
    scratch: []T,
) void {
    const Context = struct {
        items: []T,
        scratch: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), i: usize, j: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[i], ctx.items[j]);
        }

        pub fn swap(ctx: @This(), i: usize, j: usize) void {
            mem.swap(T, &ctx.items[i], &ctx.items[j]);
        }

        pub fn copyToScratch(ctx: @This(), src: usize, scratch_idx: usize) void {
            ctx.scratch[scratch_idx] = ctx.items[src];
        }

        pub fn copyFromScratch(ctx: @This(), scratch_idx: usize, dst: usize) void {
            ctx.items[dst] = ctx.scratch[scratch_idx];
        }
    };

    sortContext(0, items.len, Context{
        .items = items,
        .scratch = scratch,
        .sub_ctx = context,
    });
}

/// Context must provide: lessThan, swap, copyToScratch, copyFromScratch
pub fn sortContext(start: usize, end: usize, context: anytype) void {
    // Algorithm implementation
    _ = start;
    _ = end;
    _ = context;
}

```

**Possible algorithms to consider:

1. (Logsort)[https://github.com/aphitorite/Logsort]
  - QuickSort variant
  - O(n log n) average case time complexity (worst case depends on partitioning scheme) (sayhisort author alledges it degrages to O(n^2) in worst case)
  - O(log n) space complexity (in practice a smaller constant factor than Wikisort)
  - non adaptive, usually fastest on random data sets but slower on partially sorted data sets than adaptive algorithms
  - The C implementation appears to be much faster when compiled with clang than gcc
  - MIT License
  - [Wiki entry](https://sortingalgos.miraheze.org/wiki/Logsort)
 
2. (Wikisort)[https://github.com/BonzaiThePenguin/WikiSort]
  - Block Merge Sort variant
  - O(n log n) time complexity
  - O(1) space complexity (512 element scratch space) (this scratch space has been notes to be a stack overflow risk for Tigerbeetle)
  - incredibly adaptive, very fast on partially sorted data sets due to some magic with the cache I believe
  - MIT License
  - current std.sort implementation is based on this algorithm
	- not as fast as the other algorithms here, and scratch space is in practice larger than the O(log n) of other algorithms
	- [Wiki entry](https://sortingalgos.miraheze.org/wiki/WikiSort) 

3. (Blitsort)[https://github.com/scandum/blitsort]
  - rotate quick/merge sort hybrid variant
  - O(n log^2 n) average and worst case time complexity (in practice faster than Wikisort)
  - O(1) variable 32-512 element scratch space depending on performance requirements
  - adaptive
  - Unlicense license

4. (Sayhisort)[https://github.com/grafi-tt/sayhisort]
  - Block Merge Sort variant (based on GrailSort) 
  - O(n log n) time complexity
  - truely in place O(1) space complexity (this could be ideal as it removes the stack overflow risk of Wikisort and simplifies the api compared to algorithms requiring scratch space)
  - appears somewhat adaptive
  - probably going to be the hardest to implement of the algorithms here due to its complexity
  - CC0-1.0 license

5. (ForSort)[https://github.com/stew675/ForSort]
  - Block Merge Sort variant
  - O(n log n) time complexity
  - O(log n) space complexity
  - adaptive
  - LGPL-2.1 license (Likely incompatible with Zig stdlib but authors permission could be sought)

6. (Helium Sort)[https://git.a-a.dev/amari/Helium-Sort]
  - Block Merge Sort variant
  - O(n log n) time complexity
  - O(1) space complexity there is a true in place variant but it is slightly slower, so benchmarking is required here
  - adaptive
  - MIT Licenseg

7. (DustSort)[https://github.com/bzyjin/dustsort]
    - Block Merge Sort variant
    - O(n log n) time complexity
    - O(1) space complexity (with a fixed sized buffer - I'm unsure of the size currently)
    - adaptive
    - MIT License