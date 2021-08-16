COUNTERS = {
    'packets', 'unicast packets',
    'bytes', 'error packets', 'discard packets', 'pause packets'
}


def name_to_metric(name: str) -> str:
    return 'switch_port_' + name.replace(' ', '_') + '_total'
