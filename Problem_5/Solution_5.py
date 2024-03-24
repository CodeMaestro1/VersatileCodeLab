import os
import time

def source_process(data, write_end):
  try:
    #Write data to pipe
    for item in data:
        os.write(write_end, f"{item}\n".encode())
        time.sleep(1)
  except OSError as e:
    print(f"Writing to pipe failed: {e}")
  finally:
    try:
      #Close the write end of the pipe when done
      os.close(write_end)
    except OSError as e:
       print(f"Closing write end of pipe failed: {e}")

def transformer_process(read_end, fifo_path):
  try:
    # Close the write end of the pipe in the child process, because we don't need it
    os.close(read_end[1])

    # Open the FIFO pipe in write mode
    fifo = os.open(fifo_path, os.O_WRONLY)

    # Initialize tokens to an empty list
    tokens = []

    while True:
        # Read data from the pipe (anonymous pipe)
        data = os.read(read_end[0], 1024)

        # If there are no data to read in the anonymous pipe, break the loop
        if not data:
            break

        # Tokenize the data
        tokens = data.decode().split()
  except OSError as e:
    print(f"Error in transformer process: {e}")
  finally:
     try:
       # Write the tokens to the FIFO pipe
        for token in tokens:
            os.write(fifo, f"{token}\n".encode())

        # Close the read end of the pipe (anonymous pipe) and the FIFO pipe when done
        os.close(read_end[0])
        os.close(fifo)
     except OSError as e:
        print(f"Closing pipes failed: {e}")

def output_process(fifo_path):
  try:
    fifo = os.open(fifo_path, os.O_RDONLY)
    result = ""
  except OSError as e:
    print(f"Error when opening the read end of FIFO pipe: {e}")
  try:
    while True:
        data = os.read(fifo, 1024)

        if not data:
            break

        result += data.decode()
  except OSError as e:
    print(f"Error reading data from FIFO pipe: {e}")
  try:
    os.close(fifo)
  except OSError as e:
      print(f"The FIFO pipe couldn't close: {e}")
  return result

def main():

    #Create a pipe
    pipe = os.pipe()

    #Create FIFO pipe
    fifo_path = "/tmp/myfifo"
    if not os.path.exists(fifo_path):
      os.mkfifo(fifo_path)

    #Fork a new child process
    pid = os.fork()

    if pid:

        os.close(pipe[0])
        source_process(["I love PLH211          ", "The professor is boring", "but the curriculum is  ", "interesting & useful   "], pipe[1])
        os.waitpid(pid, 0) #Added to avoid zombie processes and to wait for the child process to finish
    else:

        transformer_process(pipe, fifo_path)
        #os._exit(0)  # Exit the child process explicitly

    result = output_process(fifo_path)
    print(result)

if __name__ == "__main__":
   main()