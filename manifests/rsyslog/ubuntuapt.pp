#
# Copyright 2019 (c) Andrey Galkin
#


# Please see README
class cflogsink::rsyslog::ubuntuapt (
    String[1]
        $apt_url = 'http://ppa.launchpad.net/adiscon/v8-stable/ubuntu',
) {
    include cfsystem

    $release = (versioncmp($::facts['operatingsystemrelease'], '18.04') >= 0) ? {
        true    => 'bionic',
        default => $::facts['lsbdistcodename'],
    }
    if $apt_url {
        apt::key {'rsyslog':
            id      => 'AB1C1EF6EDB5746803FE13E00F6DD8135234BF2B',
            server  => 'not.valid.server',
            content => '
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: SKS 1.1.6
Comment: Hostname: keyserver.ubuntu.com

mI0EUwItYAEEALrIMClrWcovMonWFWTjMpXnNmowTxHT/e2IhZ6J40mKhGWa2Y4iqfPVZgVw
ZFaQ7BuNKjV8lIByFGiI11V+ASNFvxOwVR/iX6RsQ4k3iCp+dOlcuO7u6XNeb4otkpfyYgmU
lMfsyj+rQwnzoInPgjQsFf6M/+aMetNG+SIidX/HABEBAAG0GUxhdW5jaHBhZCBQUEEgZm9y
IEFkaXNjb26IuAQTAQIAIgUCUwItYAIbAwYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AACgkQ
D23YE1I0vysxrgP/Y+oWmi3uY/KqfHdsD/cH/BicOFoAAhDembljG/UaAk4XUEv8sHzuZO12
U4hyR4btrEnUfaRNDf+vLVkZwOWupcWVfJiLduvZSbpFydgHQgaA0cdk7FZSreIY63BumoZz
VhMkPOtyX5joVHQPM/+xvpqAJKhuj+bSTGullYduGsQ=
=pZOe
-----END PGP PUBLIC KEY BLOCK-----
',
        }
        apt::source { 'rsyslog':
            location => $apt_url,
            release  => $release,
            repos    => 'main',
            pin      => $cfsystem::apt_pin + 1,
            require  => Apt::Key['rsyslog'],
        }
    }
}
