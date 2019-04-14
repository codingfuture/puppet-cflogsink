#
# Copyright 2019 (c) Andrey Galkin
#


# Please see README
class cflogsink::rsyslog::debianapt (
    Optional[String[1]]
        $apt_url = undef,
) {
    include cfsystem

    $base_apt_url = 'http://download.opensuse.org/repositories/home:/rgerhards/'

    if versioncmp($::facts['operatingsystemrelease'], '9') >= 0 {
        $release = 'stretch'
        $fact_apt_url = pick(
            $apt_url,
            "${base_apt_url}/Debian_9.0/"
        )
    } else {
        $release = $::facts['lsbdistcodename']
        $fact_apt_url = pick(
            $apt_url,
            "${base_apt_url}/Debian_${::facts['operatingsystemrelease']}.0/"
        )
    }

    if $apt_url {
        apt::key {'rsyslog':
            id      => '4B2686292312675EE69DD7E3C6326869D2017333',
            server  => 'not.valid.server',
            content => '
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2.0.15 (GNU/Linux)

mQENBFogHPcBCADO5uSGNsR1DXvn7VZYEF7aiSEtseKhlBSv+HFRjhLXOXXIQxMA
tvRAAy8P7NKuVSOZhu3WwWXArwJpLrjPeJO2gNgFCUmhGarMz0lsM/YSqrHdRD58
AHQbPmn3abLyhavNpL41S/BSxZAmGtHQwcAWQeCNHI+Lmln6aoEilSm41tk2GqNN
O86mlLp9fMZ4K6H0eiVR6HgsMHiHxrlUVL/EdW7HXwLdM9RiwFt8XXPzYLWEv315
mvVR8KjXl3GRkIGgbNXIEzkZceFwPvhsQbw88b1XG0g/qHCW1WxGUoQEy3odGGWL
MHDJrKHOQA0UU2WGIasPrUhgNRpuHkbHYmRTABEBAAG0PmhvbWU6cmdlcmhhcmRz
IE9CUyBQcm9qZWN0IDxob21lOnJnZXJoYXJkc0BidWlsZC5vcGVuc3VzZS5vcmc+
iQE+BBMBCAAoBQJaIBz3AhsDBQkEHrAABgsJCAcDAgYVCAIJCgsEFgIDAQIeAQIX
gAAKCRDGMmhp0gFzM4FMB/9SMSdlkSOiPr/XlRfcrvsBDrCpWyY/bNjrL+IGU8bu
dsJINrb3D1M3OP+FJOv8E601uPSUvgCEqbHw+kCgmZmaJ1ewkmmCqXjbvU1b2sD2
X26vLAB8y8L/EWi/sq8vBFkYOiPLX/RhhBSaarhtWnskH/zWmKYY6BQRMaV5BGDO
TzUx0MfrmctYNgxwQrgxyYQ3KjN0I9hkVioNBr1W9u4Gyhq6o+xdXzuQ2xv3vmOT
91fBWuVPc5HhVSx4+08eVlsw+rVxIUGANwfGjLclgcI/wuUJrw+LeqNbPQ3sPoTf
nIhsWr4+ZzxFfkwTaS1KXfEbmuydHhifCCC074XBNt2TiEYEExECAAYFAlogHPcA
CgkQOzARt2udZSMbSgCcDLk8qJzcrcYQQltycwTLh/kyRRMAn20G2HGBZyBUZfDS
VpSCqs9D451g
=R0Mt
-----END PGP PUBLIC KEY BLOCK-----
',
        }
        apt::source { 'rsyslog':
            location => $apt_url,
            release  => $release,
            repos    => '/',
            pin      => $cfsystem::apt_pin + 1,
            require  => Apt::Key['rsyslog'],
        }
    }
}
