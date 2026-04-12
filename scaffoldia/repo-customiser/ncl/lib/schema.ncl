# Rhodium Standard Schema
{
  Project = {
    name | String,
    short_alias | String,
    version | String,
    stability | [| 'Alpha, 'Beta, 'Stable, 'LTS |] | default = 'Alpha,
  },

  Deployment = {
    priority_route | [| 'podman, 'nala, 'ostree, 'native |] | default = 'podman,
    targets | Array String,
    cloud_mounts | Array {
      name | String,
      path | String,
      protocol | [| 'rclone, 'fuse, 'nfs |],
    },
  },
}
