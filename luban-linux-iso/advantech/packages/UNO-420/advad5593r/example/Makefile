CC = gcc
CFLAGS = -O

all:test_iio_ad5593r 

test_iio_ad5593r: test_iio_ad5593r.c
	$(CC) $(CFLAGS) -o test_iio_ad5593r test_iio_ad5593r.c -liio
	@sync

clean:
	@rm -f *.o test_iio_ad5593r 
