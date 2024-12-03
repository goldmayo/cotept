import { AuthErrorMessage } from "@/common/constants/error.constants"
import { UserRole } from "@/modules/users/enums/user-role.enum"
import { CanActivate, ExecutionContext, Injectable } from "@nestjs/common"
import { Reflector } from "@nestjs/core"
import { AuthException } from "../exceptions/auth.exception"

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>(
      "roles",
      [context.getHandler(), context.getClass()],
    )

    if (!requiredRoles) {
      return true
    }

    const { user } = context.switchToHttp().getRequest()

    if (!requiredRoles.includes(user.role)) {
      throw new AuthException({
        code: "FORBIDDEN",
        message: AuthErrorMessage.AUTH.FORBIDDEN,
      })
    }

    return true
  }
}
