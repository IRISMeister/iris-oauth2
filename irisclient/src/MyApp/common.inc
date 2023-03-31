ROUTINE MyApp.common [Type=INC]
 ;#define APP	"USER_CLIENT_APP"
#define APP	##expression(""""_$NAMESPACE_"_CLIENT_APP"_"""")