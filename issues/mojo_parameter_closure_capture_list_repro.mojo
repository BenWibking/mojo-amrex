from std.collections import List


def apply[body_type: def() raises -> Int](body: body_type) raises -> Int:
    return body()


def main() raises:
    var src = List[Int](length=1, fill=2)

    def compute() raises {var src^} -> Int:
        return src[0]

    print(apply(compute))
