from mojo_closure_capture_pkg import Box


def main() raises:
    var box = Box()

    def use_box() raises {var box^}:
        pass
