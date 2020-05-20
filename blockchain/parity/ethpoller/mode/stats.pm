#
# Copyright 2020 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package blockchain::parity::ethpoller::mode::stats;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use bigint;
use Digest::MD5 qw(md5_hex);

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'block', cb_prefix_output => 'prefix_output_block', type => 0 },
        { name => 'transaction', cb_prefix_output => 'prefix_output_transaction', type => 0 }
    ];

    $self->{maps_counters}->{block} = [
       { label => 'block-frequency', nlabel => 'parity.stats.block.perminute', set => {
                key_values => [ { name => 'block_count', per_minute => 1 }, { name => 'last_block' }, { name => 'last_block_ts' } ],
                per_minute => 1,
                closure_custom_output => $self->can('custom_block_output'),
                perfdatas => [
                    { label => 'block', value => 'block_count', template => '%.2f' }
                ],
            }
        }
    ];

    $self->{maps_counters}->{transaction} = [
       { label => 'transaction_frequency', nlabel => 'parity.stats.transaction.perminute', set => {
                key_values => [ { name => 'transaction_count', per_minute => 1 } ],
                per_minute => 1,
                output_template => "Transaction frequency: %.2f (tx/min)",
                perfdatas => [
                    { label => 'transaction', value => 'transaction_count_per_minute', template => '%.2f' }
                ],                
            }
        }
    ];
}

sub custom_block_output {
    my ($self, %options) = @_;

    return sprintf(
        "Count: '%.2f', Last block ID: '%s', Last block timestamp '%s' ",
        $self->{result_values}->{block_count},
        $self->{result_values}->{last_block},
        $self->{result_values}->{last_block_ts}
    );
}


sub prefix_output_block {
    my ($self, %options) = @_;

    return "Block stats '";
}

sub prefix_output_fork {
    my ($self, %options) = @_;

    return "Fork stats '";
}

sub prefix_output_transaction {
    my ($self, %options) = @_;

    return "Transaction stats '";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1, statefile => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-name:s" => { name => 'filter_name' },
    });
   
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{cache_name} = "parity_ethpoller_" . $self->{mode} . '_' . (defined($self->{option_results}->{hostname}) ? $self->{option_results}->{hostname} : 'me') . '_' .
           (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));

    my $result = $options{custom}->request_api(url_path => '/stats');

    my $last_block = $result->{block}->{count};
    my $last_block_timestamp = (defined($result->{block}->{timestamp}) && $result->{block}->{timestamp} != 0) ?
                                    localtime($result->{block}->{timestamp}) :
                                    'NONE';

    $self->{block} = { block_count => $result->{block}->{count},
                        last_block => $last_block,
                       last_block_ts => $last_block_timestamp };

    $self->{transaction} = { transaction_count => $result->{transaction}->{count} };

    if ($result->{transaction}->{count} > 0) {
        my $tx_timestamp = $result->{transaction}->{timestamp} == 0 ? '' : localtime($result->{transaction}->{timestamp});
        $self->{output}->output_add(severity  => 'OK', long_msg => 'Last transaction (#' . $result->{transaction}->{count} . ') was on ' . $tx_timestamp);
    } else {
        $self->{output}->output_add(severity  => 'OK', long_msg => 'No transaction...');
    }
  
    if ($result->{transaction}->{count} > 0) {
        my $fork_timestamp = $result->{fork}->{timestamp} == 0 ? '' : localtime($result->{fork}->{timestamp});
        $self->{output}->output_add(severity  => 'OK', long_msg => 'Last fork (#' . $result->{fork}->{count} . ') was on ' . $fork_timestamp);   
    } else {
        $self->{output}->output_add(severity  => 'OK', long_msg => 'No fork occurence...');
    }
}

1;

__END__

=head1 MODE

Check Parity eth-poller for stats 

=cut

