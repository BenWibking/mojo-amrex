from std.collections import List


fn apply[body: fn() capturing -> Int]() -> Int:
    return body()


fn main():
    var src = List[Int](length=1, fill=2)

    @parameter
    fn compute() -> Int:
        return src[0]

    print(apply[compute]())
