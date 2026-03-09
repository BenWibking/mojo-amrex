from std.collections import List


fn apply[body: fn() capturing -> String]() -> String:
    return body()


fn main():
    var src = List[String](length=1, fill=String("x"))

    @parameter
    fn compute() -> String:
        return src[0]

    print(apply[compute]())
