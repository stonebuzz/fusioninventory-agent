package FusionInventory::Agent::Tools::Hardware::Generic;

use strict;
use warnings;

use FusionInventory::Agent::Tools::Network;
use FusionInventory::Agent::Tools::SNMP;

sub setConnectedDevicesMacAddresses {
    my (%params) = @_;

    my $results = $params{results};
    my $ports   = $params{ports};
    my $model   = $params{model};

    foreach my $oid (sort keys %{$results->{dot1dTpFdbAddress}}) {
        my $mac = $results->{dot1dTpFdbAddress}->{$oid};
        $mac = alt2canonical($mac);
        next unless $mac;

        # get port key
        my $portKey_part = $oid;
        $portKey_part =~ s/$model->{WALK}->{dot1dTpFdbAddress}->{OID}\.//;
        next unless $portKey_part;
        my $portKey = $model->{WALK}->{dot1dTpFdbPort}->{OID} . '.' . $portKey_part;

        # get interface key from port key
        my $ifKey_part = $results->{dot1dTpFdbPort}->{$portKey};
        next unless defined $ifKey_part;
        my $ifKey = $model->{WALK}->{dot1dBasePortIfIndex}->{OID} . '.' . $ifKey_part;

        # get interface index
        my $ifIndex = $results->{dot1dBasePortIfIndex}->{$ifKey};
        next unless defined $ifIndex;

        my $port = $ports->{$ifIndex};

        # this device has already been processed through CDP/LLDP
        next if $port->{CONNECTIONS}->{CDP};

        # this is port own mac address
        next if $port->{MAC} && $port->{MAC} eq $mac;

        # create a new connection with this mac address
        push
            @{$port->{CONNECTIONS}->{CONNECTION}->{MAC}},
            $mac;
    }
}

sub setConnectedDevices {
    my (%params) = @_;

    if      ($params{results}->{cdpCacheAddress}) {
        setConnectedDevicesUsingCDP(%params);
    } elsif ($params{results}->{lldpRemChassisId}) {
        setConnectedDevicesUsingLLDP(%params);
    }
}

sub setConnectedDevicesUsingCDP {
    my (%params) = @_;

    my $results = $params{results};
    my $ports   = $params{ports};
    my $model   = $params{model};

    while (my ($oid, $ip) = each %{$results->{cdpCacheAddress}}) {
        $ip = hex2canonical($ip);
        next if $ip eq '0.0.0.0';

        my $port_number =
            getElement($oid, -2) . "." .
            getElement($oid, -1);

        my $mac;
        my $sysname = $results->{cdpCacheDeviceId}->{$model->{WALK}->{cdpCacheDeviceId}->{OID} . "." . $port_number};
        if ($sysname =~ /^SIP([A-F0-9a-f]*)$/) {
            $mac = alt2canonical("0x".$1);
        }

        my $connection = {
            IP      => $ip,
            MAC     => $mac,
            IFDESCR => $results->{cdpCacheDevicePort}->{
                $model->{WALK}->{cdpCacheDevicePort}->{OID} . "." . $port_number
            },
            SYSDESCR => $results->{cdpCacheVersion}->{
                $model->{WALK}->{cdpCacheVersion}->{OID} . "." . $port_number
            },
            SYSNAME  => $sysname,
            MODEL => $results->{cdpCachePlatform}->{
                $model->{WALK}->{cdpCachePlatform}->{OID} . "." . $port_number
            }
        };

        next if !$connection->{SYSDESCR} || !$connection->{MODEL};

        $ports->{getElement($oid, -2)}->{CONNECTIONS} = {
            CDP        => 1,
            CONNECTION => $connection
        };
    }
}

sub setConnectedDevicesUsingLLDP {
    my (%params) = @_;

    my $results = $params{results};
    my $ports   = $params{ports};
    my $model   = $params{model};

    while (my ($oid, $mac) = each %{$results->{lldpRemChassisId}}) {

        my $port_number =
            getElement($oid, -3) . "." .
            getElement($oid, -2) . "." .
            getElement($oid, -1);

        $ports->{getElement($oid, -2)}->{CONNECTIONS} = {
            CDP        => 1,
            CONNECTION => {
                SYSMAC => alt2canonical($mac),
                IFDESCR => $results->{lldpRemPortDesc}->{
                    $model->{WALK}->{lldpRemPortDesc}->{OID} . "." . $port_number
                },
                SYSDESCR => $results->{lldpRemSysDesc}->{
                    $model->{WALK}->{lldpRemSysDesc}->{OID} . "." . $port_number
                },
                SYSNAME  => alt2canonical($results->{lldpRemSysName}->{
                    $model->{WALK}->{lldpRemSysName}->{OID} . "." . $port_number
                }),
                IFNUMBER => $results->{lldpRemPortId}->{
                    $model->{WALK}->{lldpRemPortId}->{OID} . "." . $port_number
                }
            }
        };
    }
}

sub setTrunkPorts {
    my (%params) = @_;

    my $results = $params{results};
    my $ports   = $params{ports};

    while (my ($oid, $trunk) = each %{$results->{vlanTrunkPortDynamicStatus}}) {
        $ports->{getLastElement($oid)}->{TRUNK} = $trunk ? 1 : 0;
    }
}

1;
__END__

=head1 NAME

FusionInventory::Agent::Tools::Hardware::Generic - Generic hardware-relatedfunctions

=head1 DESCRIPTION

This module provides some generic implementation of hardware-related functions.

=head1 FUNCTIONS

=head2 setConnectedDevicesMacAddresses(%params)

set mac addresses of connected devices.

=over

=item results raw values collected through SNMP

=item ports device ports list

=item walks model walk branch

=back

=head2 setConnectedDevices

Set connected devices using CDP if available, LLDP otherwise.

=over

=item results raw values collected through SNMP

=item ports device ports list

=item walks model walk branch

=back

=head2 setConnectedDevicesUsingCDP

Set connected devices using CDP

=over

=item results raw values collected through SNMP

=item ports device ports list

=item walks model walk branch

=back

=head2 setConnectedDevicesUsingLLDP

Set connected devices using LLDP

=over

=item results raw values collected through SNMP

=item ports device ports list

=item walks model walk branch

=back

=head2 setTrunkPorts

Set trunk flag on ports needing it.

=over

=item results raw values collected through SNMP

=item ports device ports list

=back
