from std.collections import List


def apply[body_type: def() raises -> String](body: body_type) raises -> String:
    return body()


def main() raises:
    var src = List[String](length=1, fill=String("x"))

    def compute() raises {var src^} -> String:
        return src[0].copy()

    print(apply(compute))
