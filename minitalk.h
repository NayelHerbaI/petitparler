/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   minitalk.h                                         :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: jihi <jihi@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/02/15 02:37:41 by jihi              #+#    #+#             */
/*   Updated: 2026/02/15 02:46:04 by jihi             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#ifndef MINITALK_H
# define MINITALK_H

# include <unistd.h>
# include <signal.h>

/* utils */
void	ft_putchar(char c);
void	ft_putstr(char *str);
void	ft_putnbr(int nb);
int		ft_isdigits(char *s);
int		ft_atoi(char *s);
void	wait_ack(void);

/* client */
int		parse_pid(char *s);
void	setup_ack_signal(void);
int		send_char(int pid, unsigned char c);

/* server */
void	setup_signals(void);
int		parse_pid(char *s);
void	server_get_handler(struct sigaction *sa);

#endif
