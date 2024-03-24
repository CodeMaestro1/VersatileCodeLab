import os
import time

def create_child(level, index):
    pid = os.fork()

    if pid == 0:
        # This is the child process
        print(f"I am Child[{level}.{index}] with pid: {os.getpid()} and my Parent id: {os.getppid()}")
        time.sleep(1)

        if level == 1 and index == 1:  # B
            create_child(level + 1, 1)  # D
            create_child(level + 1, 2)  # E
        elif level == 1 and index == 2:  # C
            create_child(level + 1, 3)  # F
        elif level == 2 and index == 1:  # D
            create_child(level + 1, 1)  # W
        elif level == 2 and index == 2:  # E
            create_child(level + 1, 2)  # Z
            create_child(level + 1, 3)  # X
        elif level == 2 and index == 3:  # F
            create_child(level + 1, 4)  # T
        elif level == 3 and index == 1:  # W
            create_child(level + 1, 1)  # Q
        elif level == 3 and index == 2:  # Z
            create_child(level + 1, 2)  # V
            create_child(level + 1, 3)  # N
        elif level == 3 and index == 3:  # X
            create_child(level + 1, 4)  # M
        elif level == 3 and index == 4:  # T
            create_child(level + 1, 5)  # L

        os._exit(0)

    # This is the parent process
    os.waitpid(pid, 0)

def create_tree():
    print(f"I am Parent[0] of all, my PID is {os.getpid()}")

    create_child(1, 1)  # B
    create_child(1, 2)  # C

if __name__ == "__main__":
    create_tree()

##### expected output #####
#     A (Parent[0])
# ├─ B (Child[1.1])
# │  ├─ D (Child[2.1])
# │  │  └─ W (Child[3.1])
# │  │     └─ Q (Child[4.1])
# │  └─ E (Child[2.2])
# │     ├─ Z (Child[3.2])
# │     │  ├─ V (Child[4.2])
# │     │  └─ N (Child[4.3])
# │     └─ X (Child[3.3])
# │        └─ M (Child[4.4])
# └─ C (Child[1.2])
#    └─ F (Child[2.3])
#       └─ T (Child[3.4])
#          └─ L (Child[4.5])