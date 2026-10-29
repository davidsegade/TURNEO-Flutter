export const registrationLocalUserIds = ['u4', 'u5'] as const;

export function isAllowedRegistrationUser(
    localUserId: unknown): localUserId is 'u4' | 'u5' {
  return typeof localUserId === 'string' &&
      registrationLocalUserIds.includes(localUserId as 'u4' | 'u5');
}
