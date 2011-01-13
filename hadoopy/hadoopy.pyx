#!/usr/bin/env python
# (C) Copyright 2010 Brandyn A. White
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

__author__ = 'Brandyn A. White <bwhite@cs.umd.edu>'
__license__ = 'GPL V3'

import sys
import os
from operator import itemgetter
from itertools import groupby
import typedbytes

cdef extern from "stdlib.h":
    void *malloc(size_t size)
    void free(void *ptr)

cdef extern from "stdio.h":
    ssize_t getdelim(char **lineptr, size_t *n, int delim, void *stream)
    void *stdin
    int getchar()
    size_t fread(void *ptr, size_t size, size_t nmemb, void *stream)

cdef extern from "endian.h":
    int be32toh(int val)
    long be64toh(long val)
           

cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *s, Py_ssize_t len)

# Begin TB
cdef _read_int():
    """Read integer

    Code: 3
    Format: <32-bit signed integer>

    Returns:
        Signed int
    """
    cdef int val
    fread(&val, 4, 1, stdin)  # = 1
    return int(be32toh(val))
    #return (sz[0] << 24) + (sz[1] << 16) + (sz[2] << 8) + sz[3]


cdef _read_long():
    """Read integer

    Code: 4
    Format: <64-bit signed integer>

    Returns:
        Signed long
    """
    cdef long val
    fread(&val, 8, 1, stdin)  # = 1
    return int(be64toh(val))

cdef _read_float():
    """Read float

    Code: 5
    Format: <32-bit IEEE floating point number>

    Returns:
        Signed int
    """
    cdef int val
    fread(&val, 4, 1, stdin)  # = 1
    val = be32toh(val)
    return float((<float*>&val)[0])


cdef _read_double():
    """Read double

    Code: 6
    Format: <64-bit IEEE floating point number>

    Returns:
        Signed long
    """
    cdef long val
    fread(&val, 8, 1, stdin)  # = 1
    val = be64toh(val)
    return float((<double*>&val)[0])


cdef _read_byte():
    """Read integer

    Code: 1
    Format: <signed byte>

    Returns:
        Signed int
    """
    cdef signed char val
    fread(&val, 1, 1, stdin) # = 1
    return int(val)


cdef _read_bool():
    """Read integer

    Code: 2
    Format: <signed byte (0 = false and 1 = true)>

    Returns:
        Bool
    """
    return bool(_read_byte())


cdef _read_bytes():
    """Read raw bytes

    Code: 0
    Format: <32-bit signed integer> <as many bytes as indicated by the integer>

    Returns:
        Python string of bytes
    """
    sz = _read_int()
    print(sz)
    cdef char *bytes = <char*>malloc(sz)
    fread(bytes, sz, 1, stdin) # = 1
    out = PyString_FromStringAndSize(bytes, sz)
    free(bytes)
    return out


cdef _read_vector():
    """Read fixed length vector of typedbytes

    Code: 8
    Format: <32-bit signed integer> <as many typed bytes sequences as indicated by the integer>

    Returns:
        Python tuple with nested values
    """
    sz = _read_int()
    out = []
    for x in range(sz):
        out.append(_read_tb_code())
    return tuple(out)


cdef _read_list():
    """Read variable length list of typedbytes

    Code: 9
    Format: <variable number of typed bytes sequences> <255 written as an unsigned byte>

    Returns:
        Python list of nested values
    """
    out = []
    while True:
        try:
            out.append(_read_tb_code())
        except StopIteration:
            break
    return out


cdef _read_dict():
    """Read fixed length pairs of typedbytes (interpreted as a dict/map)

    Code: 10
    Format: <32-bit signed integer> <as many (key-value) pairs of typed bytes sequences as indicated by the integer>

    Returns:
        Python dict with nested values
    """
    sz = _read_int()
    out = []
    for x in range(sz):
        kv = _read_tb_code(), _read_tb_code()
        out.append(kv)
    return dict(out)


# TODO Make this a function pointer array
#_tb_codes = (_read_bytes,)
#             _read_byte, _read_bool, _read_int, _read_long, _read_float,
#     _read_double, _read_string, _read_vector, _read_list, _read_dict)
def _read_tb_code():
    cdef unsigned char type_code = getchar()
    if type_code == 0:
        return _read_bytes()
    elif type_code == 1:
        return _read_byte()
    elif type_code == 2:
        return _read_bool()
    elif type_code == 3:
        return _read_int()
    elif type_code == 4:
        return _read_long()
    elif type_code == 5:
        return _read_float()
    elif type_code == 6:
        return _read_double()
    elif type_code == 7:
        return _read_bytes()
    elif type_code == 8:
        return _read_vector()
    elif type_code == 9:
        return _read_list()
    elif type_code == 10:
        return _read_dict()
    elif type_code == 255:
        raise StopIteration
    else:
        raise IndexError('Bad index %d ' % type_code)

cdef __one_key_value_tb():
    k = _read_tb_code()
    print(k)
    v = _read_tb_code()
    return k, v

def read_tb():
    return __one_key_value_tb()

# End TB

cdef __one_key_value_text():
    cdef ssize_t sz
    cdef char *lineptr = NULL
    cdef size_t n = 0
    sz = getdelim(&lineptr, &n, ord('\t'), stdin)
    if sz == -1:
        raise StopIteration
    k = PyString_FromStringAndSize(lineptr, sz - 1)
    free(lineptr)
    sz = getdelim(&lineptr, &n, ord('\n'), stdin)
    if sz == -1:
        raise StopIteration
    v = PyString_FromStringAndSize(lineptr, sz - 1)
    free(lineptr)
    return k, v

def _one_key_value_text():
    return __one_key_value_text()

#def _one_key_value_text_slow():
#    return sys.stdin.readline().x[:-1].split('\t', 1)

def _one_key_value_tb():
    return typedbytes.PairedInput(sys.stdin).read()

class KeyValueStream(object):
    def __init__(self, key_value_func):
        self._key_value_fun = key_value_func
        self._prev = None
        self._done = False

    def __iter__(self):
        return self

    def next(self):
        if self._prev:
            prev = self._prev
            self._prev = None
            return prev
        if self._done:
            raise StopIteration
        try:
            return self._key_value_fun()
        except StopIteration, e:
            self._done = True
            raise e

    def put(self, value):
        self._prev = value


class GroupedValues(object):
    def __init__(self, group_key, key_value_iter):
        self._key_value_iter = key_value_iter
        self._group_key = group_key
        self._done = False

    def __iter__(self):
        return self

    def next(self):
        if self._done:
            raise StopIteration
        try:
            k, v = self._key_value_iter.next()
        except StopIteration, e:
            self._done = True
            raise e
        # If we get to the end, put the value back
        if k != self._group_key:
            self._done = True
            self._key_value_iter.put((k, v))
            raise StopIteration
        return v


class GroupedKeyValues(object):
    def __init__(self, key_value_iter):
        self._key_value_iter = key_value_iter
        self._prev = None
        self._done = False

    def __iter__(self):
        return self

    def next(self):
        if self._done:
            raise StopIteration
        # Exhaust prev
        if self._prev:
            for x in self._prev:
                pass
        try:
            k, v = self._key_value_iter.next()
        except StopIteration, e:
            self._done = True
            raise e
        self._key_value_iter.put((k, v))
        self._prev = GroupedValues(k, self._key_value_iter)
        return k, self._prev


_line_count = 0
cdef __one_offset_value_text():
    global _line_count
    cdef ssize_t sz
    cdef char *lineptr = NULL
    cdef size_t n = 0
    sz = getdelim(&lineptr, &n, ord('\n'), stdin)
    free(lineptr)
    if sz == -1:
        raise StopIteration
    line = PyString_FromStringAndSize(lineptr, sz - 1)
    free(lineptr)
    out_count = _line_count
    _line_count += sz
    return out_count, line


def _one_offset_value_text():
    return __one_offset_value_text()


def _is_io_typedbytes():
    # Only all or nothing typedbytes is supported, just check stream_map_input
    try:
        return os.environ['stream_map_input'] == 'typedbytes'
    except KeyError:
        return False


def _read_in_map():
    if _is_io_typedbytes():
        return KeyValueStream(_one_key_value_tb)
    return KeyValueStream(_one_offset_value_text)


def _read_in_reduce():
    """
    Returns:
        Function that can be called to receive grouped input.  Function returns
        None when there is no more input.
    """
    if _is_io_typedbytes():
        return GroupedKeyValues(KeyValueStream(_one_key_value_tb))
    return GroupedKeyValues(KeyValueStream(_one_key_value_text))


def _print_out_text(iter, sep='\t'):
    for out in iter:
        if isinstance(out, tuple):
            print(sep.join([str(x) for x in out]))
        else:
            print(str(out))


def _print_out_tb(iter):
    typedbytes.PairedOutput(sys.stdout).writes(iter)


def _print_out(iter):
    """Given an iterator, output the paired values

    Args:
        iter: Iterator of (key, value)
    """
    _print_out_tb(iter) if _is_io_typedbytes() else _print_out_text(iter)


def process_inout(work_func, in_iter, out_func, attr):
    if work_func == None:
        return 1
    if isinstance(work_func, type):
        work_func = work_func()
    try:
        work_func.configure()
    except AttributeError:
        pass
    try:
        call_work_func = getattr(work_func, attr)
    except AttributeError:
        call_work_func = work_func
    for x in in_iter:
        work_iter = call_work_func(*x)
        if work_iter != None:
            out_func(work_iter)
    try:
        work_iter = work_func.close()
    except AttributeError:
        pass
    else:
        if work_iter != None:
            out_func(work_iter)
    return 0


def run(mapper=None, reducer=None, combiner=None, **kw):
    if len(sys.argv) >= 2:
        val = sys.argv[1]
        if val == 'map':
            ret = process_inout(mapper, _read_in_map(), _print_out, 'map')
        elif val == 'reduce':
            ret = process_inout(reducer, _read_in_reduce(), _print_out, 'reduce')
        elif val == 'combine':
            ret = process_inout(reducer, _read_in_reduce(), _print_out, 'reduce')
        else:
            print_doc_quit(kw['doc'])
    else:
        ret = 1
    if ret and 'doc' in kw:
        print_doc_quit(kw['doc'])
    return ret


def print_doc_quit(doc):
    print(doc)
    sys.exit(1)