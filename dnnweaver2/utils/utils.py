import math

def floor_a_by_b(a, b):
    return int(float(a) / b)

def ceil_a_by_b(a, b):
    return int(math.ceil(float(a) / b))


def log2(a):
    return math.log(a) / math.log(2)

def lookup_pandas_dataframe(data, lookup_dict):
    '''
    Lookup a pandas dataframe using a key-value dict
    '''
    data = data.drop_duplicates()
    for key in lookup_dict:
        data = data.loc[data[key] == lookup_dict[key]]

    # assert len(data) == 1, ("Found {} entries for dict {}".format(len(data), lookup_dict))
    return data

