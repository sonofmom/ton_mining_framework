from Libraries.tools import account as at
from Libraries.tvm_valuetypes import Cell

def mk_solution_boc(giver, solution, filename=None):
    if isinstance(giver, str):
        giver = at.read_friendly_address(giver)
    if isinstance(solution, str):
        solution = bytes.fromhex(solution)

    data_cell = Cell()
    for i in solution:
        data_cell.data.put_arbitrary_uint(i, 8)

    solution_cell = Cell()
    solution_cell.data.put_arbitrary_uint(0x44, 7)
    solution_cell.data.put_arbitrary_uint(0xff, 8)
    for i in giver["bytes"]:
        solution_cell.data.put_arbitrary_uint(i, 8)
    solution_cell.data.put_arbitrary_uint(1, 6)
    solution_cell.refs.append(data_cell)

    solution_boc = solution_cell.serialize_boc(has_idx=False, hash_crc32=True)

    if filename:
        fh = open(filename, "wb")
        fh.write(solution_boc)
        fh.close()
        return None
    else:
        return solution_boc
