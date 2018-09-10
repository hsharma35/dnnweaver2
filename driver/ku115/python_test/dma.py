if __name__ == "__main__":
    print('testing dma with python')
    with open('/dev/xdma/card0/h2c0') as f:
        print('opened f')
