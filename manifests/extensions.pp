# == Class nova::extensions
#
# Installs and configures nova API extensions
#
# === Parameters
#
# [*fping_ensure*]
#   (optional) Whether the nova fping extension will be active
#   Defaults to present
#
#
class nova::extensions (
  $fping_ensure = 'present',
) {

  ensure_packages(['fping'], { 'ensure' => $fping_ensure })

}
