from std.collections import List


def apply[body: def() raises capturing -> String]() raises -> String:
    return body()


def main() raises:
    var src = List[String](length=1, fill=String("x"))

    @parameter
    def compute() raises -> String:
        return src[0]

    print(apply[compute]())
