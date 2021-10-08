from multiprocessing import Pool



class Multiprocess:
    def __init__(self, dataframe):
        self.dataframe = dataframe

    def process_dataframe(self, function):
        processed_data = []
        with Pool(processes=4) as pool:
            res = pool.map(function, self.dataframe)
            processed_data = res.get(timeout=1)

            pool.close()
            pool.join()
        return processed_data


if __name__ == '__main__':
    pass