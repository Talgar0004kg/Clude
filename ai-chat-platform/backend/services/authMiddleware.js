import jwt from 'jsonwebtoken'

const SECRET = process.env.JWT_SECRET || 'dev-secret'

export function signToken(user) {
  return jwt.sign(
    { id: user.id, role: user.role, business_id: user.business_id, email: user.email, name: user.name },
    SECRET,
    { expiresIn: '7d' }
  )
}

export function auth(requiredRole) {
  return (req, res, next) => {
    const header = req.headers.authorization || ''
    const token = header.startsWith('Bearer ') ? header.slice(7) : null
    if (!token) return res.status(401).json({ error: 'no_token' })
    try {
      const payload = jwt.verify(token, SECRET)
      if (requiredRole && payload.role !== requiredRole) {
        return res.status(403).json({ error: 'forbidden' })
      }
      req.user = payload
      next()
    } catch {
      return res.status(401).json({ error: 'invalid_token' })
    }
  }
}
