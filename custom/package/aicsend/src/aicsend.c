/* 直接用 libusb 对 AIC 假光盘发 CBW，打印每一步的返回值和 CSW。
 * 用法: aicsend <vid> <pid> <hex-cbw> [<hex-cbw> ...]   (每条 CBW = 31 字节 = 62 个十六进制字符)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libusb-1.0/libusb.h>

static int hex2bin(const char *h, unsigned char *o, int max)
{
	int n = strlen(h) / 2, i;
	if (n > max) return -1;
	for (i = 0; i < n; i++) { unsigned v; sscanf(h + 2 * i, "%2x", &v); o[i] = v; }
	return n;
}

int main(int argc, char **argv)
{
	libusb_context *ctx = NULL;
	libusb_device_handle *h;
	unsigned vid, pid;
	int i, r, xfer;
	unsigned char buf[64], csw[64];
	unsigned char ep_out = 0x01, ep_in = 0x81;

	if (argc < 4) { fprintf(stderr, "usage: %s vid pid hexcbw...\n", argv[0]); return 2; }
	sscanf(argv[1], "%x", &vid); sscanf(argv[2], "%x", &pid);

	r = libusb_init(&ctx);
	if (r) { printf("init fail %d\n", r); return 1; }
	h = libusb_open_device_with_vid_pid(ctx, vid, pid);
	if (!h) { printf("open_device_with_vid_pid FAIL (no such device or no permission)\n"); return 1; }
	printf("opened %04x:%04x\n", vid, pid);

	if (libusb_kernel_driver_active(h, 0) == 1) {
		r = libusb_detach_kernel_driver(h, 0);
		printf("detach_kernel_driver -> %d (%s)\n", r, libusb_error_name(r));
	}
	r = libusb_claim_interface(h, 0);
	printf("claim_interface -> %d (%s)\n", r, libusb_error_name(r));
	if (r) return 1;

	for (i = 3; i < argc; i++) {
		int n = hex2bin(argv[i], buf, sizeof buf);
		printf("\n[CBW %d] %d bytes, tag=%02x%02x%02x%02x opcode_last=%02x\n", i - 2, n, buf[4], buf[5], buf[6], buf[7], n > 0 ? buf[n - 1] : 0);
		xfer = 0;
		r = libusb_bulk_transfer(h, ep_out, buf, n, &xfer, 3000);
		printf("  OUT -> %d (%s), wrote %d\n", r, libusb_error_name(r), xfer);
		if (r) continue;
		xfer = 0; memset(csw, 0, sizeof csw);
		r = libusb_bulk_transfer(h, ep_in, csw, 13, &xfer, 3000);
		printf("  IN(CSW) -> %d (%s), read %d:", r, libusb_error_name(r), xfer);
		for (r = 0; r < xfer; r++) printf(" %02x", csw[r]);
		if (xfer >= 13) printf("   [sig=%s status=%d]", memcmp(csw, "USBS", 4) ? "BAD" : "USBS", csw[12]);
		printf("\n");
		usleep(300000);
	}
	libusb_release_interface(h, 0);
	libusb_close(h);
	libusb_exit(ctx);
	printf("\ndone\n");
	return 0;
}
