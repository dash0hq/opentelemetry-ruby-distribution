# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    module Resource
      # Resource detector that derives `k8s.pod.uid` by parsing cgroup files,
      # gated on an `/etc/hosts` marker that indicates a Kubernetes-managed
      # environment. Ported from the Node.js distribution's
      # `opentelemetry-resource-detector-kubernetes-pod`.
      #
      # `OpenTelemetry::SDK` must be loaded before `detect` is called.
      module KubernetesPod
        ETC_HOSTS_FILE = '/etc/hosts'
        EXPECTED_FIRST_LINE_IN_ETC_HOSTS = '# Kubernetes-managed hosts file'

        POD_UID_CHARS = 36
        POD_LABEL = 'pod'
        POD_LABEL_MOUNT_PART = '/pods/'
        POD_UID_PART_CHARS = POD_UID_CHARS + POD_LABEL.length # "pod" + 36-char uid
        CONTAINER_ID_CHARS = 64

        # cgroup v1
        PROC_SELF_MOUNTINFO_FILE = '/proc/self/mountinfo'
        # cgroup v2
        PROC_SELF_CGROUP_FILE = '/proc/self/cgroup'

        # Matches slice names like "kubepods-pode462ffed_94ce_4806_a52e_d2726f448f15.slice".
        POD_UID_IN_CGROUP_LINE_REGEX =
          /\A[a-z_-]*pod(?<uid>[0-9a-f]{8}[-_][0-9a-f]{4}[-_][0-9a-f]{4}[-_][0-9a-f]{4}[-_][0-9a-f]{12})\.slice\z/

        extend self

        # The detector interface: the only public method.
        def detect
          attributes = {}
          uid = pod_uid
          attributes['k8s.pod.uid'] = uid if uid
          ::OpenTelemetry::SDK::Resources::Resource.create(attributes)
        end

        private

        # @return [String, nil] the pod uid, or nil when not on Kubernetes or not
        #   determinable.
        def pod_uid
          return nil unless kubernetes?

          pod_uid_from_cgroup_v1(candidate_lines(read_file(PROC_SELF_MOUNTINFO_FILE), POD_UID_CHARS)) ||
            pod_uid_from_cgroup_v2(candidate_lines(read_file(PROC_SELF_CGROUP_FILE), CONTAINER_ID_CHARS))
        end

        def kubernetes?
          kubernetes_managed_hosts?(read_file(ETC_HOSTS_FILE))
        end

        def kubernetes_managed_hosts?(content)
          return false if content.nil? || content.strip.empty?

          first_line = content.split("\n").first
          !first_line.nil? && first_line.start_with?(EXPECTED_FIRST_LINE_IN_ETC_HOSTS)
        end

        # cgroup v1: a mountinfo line containing "/pods/" followed by the 36-char uid.
        def pod_uid_from_cgroup_v1(lines)
          mount = lines.find do |line|
            index = line.index(POD_LABEL_MOUNT_PART)
            index&.positive?
          end
          return nil unless mount

          part_after_pod_label = mount.split(POD_LABEL_MOUNT_PART)[1]
          return nil if part_after_pod_label.nil? || part_after_pod_label.empty?

          part_after_pod_label[0, POD_UID_CHARS]
        end

        # cgroup v2: the penultimate "/"-separated segment of a cgroup line, either
        # "pod<uid>" or a "…pod<uid>.slice" name (with "_" normalized to "-").
        def pod_uid_from_cgroup_v2(lines)
          lines.each do |line|
            segments = line.split('/')
            next if segments.length <= 2

            penultimate = segments[-2]
            uid = pod_uid_from_segment(penultimate)
            return uid if uid
          end
          nil
        end

        def pod_uid_from_segment(segment)
          if segment.start_with?(POD_LABEL) && segment.length == POD_UID_PART_CHARS
            segment[POD_LABEL.length, POD_UID_CHARS]
          elsif (match = POD_UID_IN_CGROUP_LINE_REGEX.match(segment))
            match[:uid].tr('_', '-')
          else
            # Questionable: this may extract a wrong uid, but mirrors upstream's
            # last-resort behavior.
            segment
          end
        end

        def candidate_lines(content, minimum_length)
          return [] if content.nil? || content.empty?

          content.split("\n").map(&:strip).select { |line| line.length > minimum_length }
        end

        def read_file(filename)
          File.read(filename, encoding: 'utf-8')
        rescue StandardError
          nil
        end
      end
    end
  end
end
