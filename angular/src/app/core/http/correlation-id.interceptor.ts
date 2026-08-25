import { HttpInterceptorFn } from '@angular/common/http';

export const correlationIdInterceptor: HttpInterceptorFn = (request, next) => {
  const requestId = crypto.randomUUID();
  return next(request.clone({
    setHeaders: {
      'X-Request-ID': requestId,
    },
  }));
};
