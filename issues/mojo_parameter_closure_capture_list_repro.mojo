from std.collections import List


def apply[body: def() raises capturing -> Int]() raises -> Int:
    return body()


def main() raises:
    var src = List[Int](length=1, fill=2)

    @parameter
    def compute() raises -> Int:
        return src[0]

    print(apply[compute]())
