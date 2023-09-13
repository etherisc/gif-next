import argparse
import json
import os


def get_json_files(directory:str):
    return [f for f in os.listdir(directory) if f.endswith('.json') and os.path.isfile(os.path.join(directory, f))]


def read_json_file(filename):
    with open(filename, 'r') as file:
        return json.load(file)


def print_bytecode_size(json_file):

    data = read_json_file(json_file)
    bytecode = data['bytecode']
    size = int(len(bytecode)/2)
    size_kb = size/1024.0

    if size > 0:
        print(f"{json_file} {size} {size_kb:.1f}KB")


def main(directory):
    files = get_json_files(directory)

    for f in files:
        print_bytecode_size(os.path.join(directory, f))


if __name__ == "__main__":

    # prepare comand line arg parsing
    parser = argparse.ArgumentParser(description="check contract size")
    parser.add_argument('directory', type=str, help="directory containing json contract files (usually build/contracts)")

    # get/process command line args
    args = parser.parse_args()

    main(args.directory)