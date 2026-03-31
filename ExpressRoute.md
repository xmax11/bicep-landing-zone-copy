# ExpressRoute Integration Guide For This Landing Zone

## Purpose

This guide explains how to add and connect Azure ExpressRoute to the current hub-and-dual-spoke landing zone in this repository.

It is written as a process guide only (no code snippets), so you can apply it through Azure Portal and then align IaC changes in this project.

## Current Baseline You Are Starting From

- Hub VNet: `10.100.0.0/16`
- Spoke 1 VNet: `10.200.0.0/16`
- Spoke 2 VNet: `10.210.0.0/16`
- Hub Firewall: enabled
- Hub Bastion: enabled
- Hub Private DNS Resolver: enabled
- Spoke-to-hub peering exists for both spokes
- Gateway transit is currently disabled in peering settings
- `GatewaySubnet` and ExpressRoute gateway are not currently deployed by this template

## Step-By-Step Process

1. Confirm connectivity goals before building
- Decide exactly which on-premises networks must reach Azure.
- Decide which Azure subnets/services must be reachable from on-premises.
- Decide whether traffic should go directly through ExpressRoute gateway routes or be inspected by Azure Firewall.

2. Validate IP plan and avoid overlaps
- Confirm all on-premises CIDRs do not overlap with:
  - `10.100.0.0/16` (Hub)
  - `10.200.0.0/16` (Spoke 1)
  - `10.210.0.0/16` (Spoke 2)
- Reserve future CIDRs now if you plan to add more spokes.

3. Prepare the hub for an ExpressRoute gateway
- Add a dedicated `GatewaySubnet` in the hub VNet (required for Virtual Network Gateway).
- Use a gateway subnet size that supports your target gateway SKU and future scale.
- Keep `GatewaySubnet` dedicated only to gateway resources.

4. Prepare on-premises routing and BGP design
- Confirm your on-premises edge device supports ExpressRoute and BGP.
- Finalize private ASN values and BGP peering IP ranges.
- Decide route advertisement policy (which on-prem prefixes are announced to Azure).

5. Create or procure the ExpressRoute circuit
- Choose connectivity model with your provider or ExpressRoute Direct.
- Choose peering location, bandwidth, and circuit SKU.
- Complete provider-side activation until the circuit status is provisioned.

6. Configure ExpressRoute private peering
- Configure private peering on the circuit with agreed VLAN and BGP settings.
- Validate BGP session status with your provider.
- Confirm that expected on-premises routes are being advertised.

7. Deploy the Azure Virtual Network Gateway (ExpressRoute type) in the hub
- Deploy an ExpressRoute Virtual Network Gateway into the hub VNet using `GatewaySubnet`.
- Choose an appropriate gateway SKU and zone option for availability requirements.
- Wait for full provisioning before moving to connection steps.

8. Connect the hub gateway to the ExpressRoute circuit
- Create an ExpressRoute connection between the hub Virtual Network Gateway and the circuit.
- If circuit and gateway are in different subscriptions/tenants, complete authorization first.
- Confirm connection reaches a connected state.

9. Enable gateway transit in VNet peering
- Update Hub to Spoke 1 peering to allow gateway transit.
- Update Spoke 1 to Hub peering to use remote gateways.
- Update Hub to Spoke 2 peering to allow gateway transit.
- Update Spoke 2 to Hub peering to use remote gateways.
- Re-check effective routes after peering changes.

10. Align route tables with the chosen traffic model
- Current spoke route tables disable BGP propagation.
- For direct ExpressRoute-learned routes in spokes, enable BGP propagation where needed.
- If keeping firewall inspection, ensure UDR strategy and firewall rules still allow required on-prem flows.
- Validate no route conflicts between UDR entries and gateway-learned routes.

11. Align security controls
- Add/adjust NSG rules for approved on-prem source prefixes and required ports.
- Add/adjust Azure Firewall network/application rules for permitted on-prem traffic.
- Keep least-privilege access and avoid broad allow rules.

12. Align DNS resolution between on-prem and Azure
- Keep using the hub DNS Private Resolver inbound endpoint for private DNS forwarding.
- Configure on-prem DNS conditional forwarders for required Azure private DNS zones.
- Validate forward and reverse lookups from both sides.

13. Validate end-to-end connectivity
- Test from on-prem to:
  - Spoke 1 VM
  - Spoke 2 VM
  - Key Vault private endpoint
  - Storage private endpoint
- Test from Azure VMs back to on-prem systems.
- Validate latency, route symmetry, and failover behavior.

14. Update operations and monitoring
- Enable/verify gateway and connection diagnostics in Log Analytics.
- Add alerts for circuit/gateway health and BGP session state.
- Document runbooks for provider outage, route drift, and planned maintenance.

15. Fold changes back into this repository
- Update IaC definitions to include:
  - Hub `GatewaySubnet`
  - ExpressRoute Virtual Network Gateway
  - ExpressRoute connection resources
  - Peering flags for gateway transit
  - Any route-table and firewall rule updates required by your chosen routing model
- Re-run validation and deployment from this repo so manual and IaC states remain consistent.

## Recommended Rollout Order

1. Build in non-production first.
2. Validate routes and DNS thoroughly.
3. Promote to production in a planned change window.
4. Keep rollback steps ready (including temporary route reversions).

## Common Pitfalls To Avoid

- Overlapping on-prem and Azure CIDRs.
- Forgetting `GatewaySubnet` in hub VNet.
- Keeping spoke BGP propagation disabled when expecting ER-learned routes.
- Enabling gateway transit on one side of peering only.
- Missing firewall rules after route changes.
- DNS forwarding configured for some zones but not all required private endpoints.
