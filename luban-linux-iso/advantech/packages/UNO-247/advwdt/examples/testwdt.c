#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <linux/types.h>
#include <linux/watchdog.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <strings.h>

#define WDIOC_SETTIMEOUT        _IOWR(WATCHDOG_IOCTL_BASE, 6, int)
#define WDIOC_GETTIMEOUT        _IOR(WATCHDOG_IOCTL_BASE, 7, int)

int fd;

/*
 * This function simply sends an IOCTL to the driver, which in turn ticks
 * the PC WDT to reset its internal timer so it doesn't trigger
 * a computer reset.
 */
void keep_alive ( void )
{
	ioctl( fd, WDIOC_KEEPALIVE, NULL );
}

void usage ( char *filename )
{
	printf("Usage: #%s [OPTIONS]\n", filename);
	printf("OPTIONS:\n");
	printf(" -d: Disable WDT\n");
	printf(" -e: Enable WDT\n");
	printf(" -s SEC: Set timeout\n");
}

void disable ( void )
{
	int i_dis;
	int ret = 0;
	
	ret = write(fd, "V", 1);
	i_dis = WDIOS_DISABLECARD;
	ioctl( fd, WDIOC_SETOPTIONS, &i_dis );
}

/*
 * The main program. Run the program with "-d" to disable the card,
 * or "-e" to enable the card.
 */
int main ( int argc, char *argv[] )
{
	int retval = 0; 
	unsigned long timeout = 0; 
	fd_set rfds;
	struct timeval tv;
	char buf[ 256 ];

	if ( argc < 2 )
	{
		usage(argv[ 0 ]);
		exit(0);
	}

	fd = open( "/dev/watchdog", O_WRONLY );
	if ( fd == -1 ) 
	{
		printf( "WDT device not enabled.\n" );
		exit( -1 );
	}

	if ( !strncasecmp(argv[1], "-d", 2) ) 
	{  
		disable();
	}
	else if ( !strncasecmp(argv[1], "-e", 2)) 
	{ 
		int i_en;
		i_en = WDIOS_ENABLECARD;
		retval = ioctl( fd, WDIOC_SETOPTIONS, &i_en );
		if ( retval != 0 )
		{
			disable();
			exit( -1 );
		}

		printf( "WDT enabled.\n" );
		ioctl( fd, WDIOC_GETTIMEOUT, &timeout );
		printf("WDT timeout has been set to %ld seconds.\n",
				// "This sample program will reset WDT every one second.\n",
				timeout );            
		printf("You can type 'd' and press Enter to disable WDT.\n");

		while ( 1 )
		{
			// keep_alive();
			/* Watch stdin (fd 0) to see when it has input. */
			FD_ZERO(&rfds);
			FD_SET(0, &rfds);
			/* Wait up to one second */
			tv.tv_sec = 1;
			tv.tv_usec = 0;

			retval = select(1, &rfds, NULL, NULL, &tv);
			/* Don't rely on the value of tv now! */
			if (retval == -1)
				perror("select()");
			else if ( retval )
			{
				/* FD_ISSET(0, &rfds) will be true. */
				if ( fgets( buf, sizeof(buf), stdin ) == NULL )
					perror("fgets()");
				else if ( buf[ 0 ] == 'd' )
				{
					disable();
					break;
				}
				else 
					printf("Invalid input.\n"); 
			}
		} 
	} 
	else if ( !strncasecmp(argv[ 1 ], "-s", 2))
	{
		if ( argc < 3 )
		{ 
			printf( "The input is invalid!\n");
			disable();
			exit( -1 ); 
		} 
		timeout = atol( argv[ 2 ] );
		if ( ( timeout <= 0 ) || ( timeout > 255 ))
		{
			disable();
			printf("Advantch WDT: the input timeout is out of range.\n");
			printf("Please choose valid one between 1 ~ 255 seconds.\n");
			exit( -1 );
		}
		retval = ioctl( fd, WDIOC_SETTIMEOUT, &timeout );
		if ( retval != 0 )
		{
			disable();	
			printf("Advantch WDT: the input timeout is out of range.\n");
			printf("Please choose valid one between 1 ~ 255 seconds.\n");
			//printf("Especially, the timeout range of NCT6116D is 10 ~ 255 seconds.\n");
			exit( -1 );
		}
		ioctl( fd, WDIOC_GETTIMEOUT, &timeout );
		printf( "WDT timeout has been set to %ld seconds.\n", timeout ); 
		printf( "After that, WDT will reset CPU.\n");
		printf( "You can use command: \"./testwdt -d\" to disable WDT.\n");      
	}
	else 
	{
		disable();
		usage(argv[ 0 ]);
	}
	close(fd);
	return 0;
}
