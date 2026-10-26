# Battery charge limit for the Acer Swift 3 SF314-52 on Linux

This keeps the battery between 75% and 80% while the laptop is plugged in.
Once the battery reaches the limit, the charger switches to pass-through: the
laptop runs on AC and the battery sits idle instead of cycling.

The usual tools don't work on this model. The kernel has no
`charge_control_end_threshold` for it, and the
[acer-wmi-battery](https://github.com/frederik-h/acer-wmi-battery) driver
fails to load (`WMI battery status call returned a buffer of unexpected length 4`)
because this BIOS doesn't implement Acer's battery health WMI methods. I found
another way in by reading the ACPI tables and the embedded controller (EC)
memory.

> Use at your own risk. This writes one bit in EC RAM through the BIOS's own
> ACPI methods. I tested it on one SF314-52 with BIOS V1.08 (board
> `Suntory_KL`). The script refuses to run on other models and checks the
> charger ID before every write, but there is no warranty.

## Install

You need the `acpi_call` kernel module (`acpi-call-dkms` on Debian/Ubuntu,
where the installer pulls it in for you).

```
git clone https://github.com/kirakirag/acer-sf314-52-charge-limit
cd acer-sf314-52-charge-limit
sudo ./install.sh
```

A systemd timer runs `charge-limit` every minute. It sets the inhibit bit at
`STOP`% and clears it at `START`%. The EC resets the bit on reboot and on some
power events, so the timer puts it back within a minute.

## Usage

```
sudo charge-limit status          # battery %, current, inhibit state, limit
journalctl -t charge-limit        # every time the limit switched on or off
```

To change the thresholds or turn the limit off, edit `/etc/charge-limit.conf`:

```
ENABLED=1
STOP=80
START=75
```

Changes apply on the next timer run. While the limit is active, `upower` and
desktop battery widgets may keep saying "charging". The battery current in
`charge-limit status` shows what is actually happening (0 mA means idle).

`sudo ./uninstall.sh` clears the bit and removes everything.

## How it works

The DSDT reaches the EC through a mailbox. `\_SB.PCI0.LPCB.EC0.RR_M(addr)`
reads one byte of EC RAM and `WR_M(addr, value)` writes one. An Acer battery
function in the BIOS (`\H0_0`, flag `ENBC`) toggles bit 6 of EC byte `0x298`
when EC byte `0x288` is `0x0B`.

| EC address | Value | Meaning |
|---|---|---|
| `0x288` | `0x0B` | Charger ID; selects which bit `H0_0` uses |
| `0x298`, `0x299` | `0xE088` | Charger `ChargeOption` value the EC writes |
| `0x28A`, `0x28B` | `0xE098` | Charger `ChargeOption` read back |
| `0x39A`, `0x39B` | signed mA | Battery current |

The layout matches the `ChargeOption` register of TI bq247xx chargers.

Bit 6 is LEARN, which makes the battery power the system with the charger
connected. Setting it with `\H0_0 1` made the battery discharge at the
system's full load while plugged in, about 1.9 A under CPU load, and the EC
mirrored the bit into `0x28A`. That works as a force-discharge but not as a
charge limit, since the battery ends up supplying most of the laptop's energy.

Bit 0 is CHRG_INHIBIT, which stops charging while the system stays on AC.
Writing `0x89` to `0x298` dropped the battery current from +1234 mA to 0 mA,
and it stayed at 0 mA under full CPU load. The read-back at `0x28A` changed to
`0x99`, and writing `0x88` back resumed charging.

`charge-limit` only ever changes bit 0 of `0x298`.

### Things to avoid

Don't call `\H0_1`. It writes `0xC574` to battery register `0x3A`, which looks
like the battery gauge's ship (shutdown) mode: it cuts the battery off until
the charger is plugged in.

Don't leave bit 6 (LEARN) set unattended, because the battery drains while
plugged in.

## License

MIT
