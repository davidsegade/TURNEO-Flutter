import {
  isAllowedRegistrationUser,
  registrationLocalUserIds,
} from './validation.ts';

Deno.test('registration allows exactly the two unlinked roster IDs', () => {
  if (!isAllowedRegistrationUser('u4') || !isAllowedRegistrationUser('u5')) {
    throw new Error('u4 and u5 must remain registerable');
  }
  if (isAllowedRegistrationUser('u1') || isAllowedRegistrationUser('u2') ||
      isAllowedRegistrationUser('u3')) {
    throw new Error('inactive/admin IDs must not be registerable');
  }
  if (registrationLocalUserIds.join(',') !== 'u4,u5') {
    throw new Error('registration order is part of the client contract');
  }
});

Deno.test('registration rejects malformed identifiers without coercion', () => {
  for (const value of [null, undefined, '', ' U4 ', 4, {}, ['u4']]) {
    if (isAllowedRegistrationUser(value)) {
      throw new Error(`unexpected registration match for ${String(value)}`);
    }
  }
});
