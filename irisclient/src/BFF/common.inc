ROUTINE BFF.common [Type=INC]
 ;#will be "BFF_BFF_APP" on Namespace BFF
 ;#will be "BFF2_BFF_APP" on Namespace BFF2
#define APP	##expression(""""_$NAMESPACE_"_BFF_APP"_"""")